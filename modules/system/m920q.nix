# M920q manual GUI-mode switch: applies the niri specialisation to the running
# system without rebooting. Automatic HDMI-hotplug switching was removed —
# AirPlay casting runs headless via airplay-receiver (kmssink), so hotplug no
# longer implies a session change. Enter niri via the boot-menu specialisation
# or manually:
#   echo niri > /run/m920q-desired-mode && systemctl start m920q-mode-switch
# Shared between the real host (hosts/m920q) and VM integration tests.
# Script logic is NOT duplicated in tests — any behavioral change in the module
# is automatically tested. Guards with lib.mkIf (!config.hostConfig.isGui) for
# activation scripts so the niri specialisation leaf does not overwrite
# base-toplevel state.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.m920q;
in {
  options.modules.system.m920q = {
    enable = lib.mkEnableOption "M920q manual mode-switch helper";

    user = lib.mkOption {
      type = lib.types.str;
      default = "schausberger";
      description = "User for user-systemd operations (stop session, HM restart, etc.)";
    };

    modeFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/m920q-current-mode";
      description = "Path to the current-mode marker file";
    };

    stateFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/m920q-desired-mode";
      description = "Path to the desired-mode file written before manual invocation";
    };

    baseToplevelFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/m920q-base-toplevel";
      description = "Path to the base-toplevel marker (records niri-carrying toplevel)";
    };

    modeSwitchTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "Timeout for the mode-switch service (switch-to-configuration can be slow)";
    };
  };

  config = lib.mkIf cfg.enable (let
    inherit (cfg) user;

    modeSwitchScript = pkgs.writeShellScript "m920q-mode-switch" ''
      set -euo pipefail

      exec 9>/run/m920q-mode-switch.lock
      /run/current-system/sw/bin/flock -n 9 || exit 0

      # The base toplevel is the one carrying specialisation/niri; a leaf
      # toplevel's own switch-to-configuration re-activates itself, so the base
      # path is recorded at base activation time and used for both directions.
      base_toplevel=$(cat ${cfg.baseToplevelFile} 2>/dev/null || true)
      if [[ ! -d "$base_toplevel/specialisation/niri" ]]; then
        base_toplevel=/run/current-system
      fi
      headless_switch="$base_toplevel/bin/switch-to-configuration"
      gui_switch="$base_toplevel/specialisation/niri/bin/switch-to-configuration"
      hm_service="home-manager-${user}.service"

      [[ -f ${cfg.stateFile} ]] || exit 0
      desired_mode=$(cat ${cfg.stateFile})

      current_mode=""
      if [[ -f ${cfg.modeFile} ]]; then
        current_mode=$(cat ${cfg.modeFile})
      fi

      if [[ "$current_mode" == "$desired_mode" ]]; then
        exit 0
      fi

      if [[ "$current_mode" == "niri" ]]; then
        # Tear down the graphical session deterministically through the user
        # systemd manager. Stopping niri-session.target / graphical-session.target
        # also stops niri.service (BindsTo graphical-session.target), ending the
        # session and all bound services without relying on socket discovery.
        sudo -u ${user} /run/current-system/sw/bin/systemctl --user -M ${user}@ stop niri-session.target 2>/dev/null || true
        sudo -u ${user} /run/current-system/sw/bin/systemctl --user -M ${user}@ stop graphical-session.target 2>/dev/null || true
        timeout 15 ${pkgs.bash}/bin/bash -c 'while /run/current-system/sw/bin/systemctl --user -M ${user}@ is-active niri.service 2>/dev/null; do sleep 0.5; done' || true
        # Kill any stray compositor/UWSM processes that escaped the teardown.
        /run/current-system/sw/bin/pkill -u ${user} -f 'niri|uwsm' 2>/dev/null || true
        /run/current-system/sw/bin/systemctl stop greetd.service 2>/dev/null || true
      fi

      # Failures abort loudly: the service turns red in systemd and the marker
      # stays at the previous mode, so re-running after fixing the cause is
      # always safe. No retry machinery — the operator re-invokes.
      if [[ "$desired_mode" == "niri" ]]; then
        "$gui_switch" test
        /run/current-system/sw/bin/systemctl stop greetd.service 2>/dev/null || true
        /run/current-system/sw/bin/systemctl restart "$hm_service"
        # Poll instead of --wait: systemctl --wait hangs after switch-to-configuration
        # changes the system underneath the running process in QEMU VM environments.
        for _ in $(seq 1 30); do
          /run/current-system/sw/bin/systemctl is-active "$hm_service" >/dev/null 2>&1 && break
          sleep 0.5
        done
        /run/current-system/sw/bin/systemctl start greetd.service
      else
        "$headless_switch" test
        /run/current-system/sw/bin/systemctl stop graphical.target greetd.service 2>/dev/null || true
        /run/current-system/sw/bin/systemctl restart "$hm_service"
      fi

      echo "$desired_mode" > ${cfg.modeFile}
    '';

    hdmiResyncScript = pkgs.writeShellScript "m920q-hdmi-resync" ''
      set -euo pipefail

      mode="headless"
      hdmi_status_files=(/sys/class/drm/*-HDMI-A-*/status)
      if (( ''${#hdmi_status_files[@]} > 0 )) && grep -qsx "connected" "''${hdmi_status_files[@]}"; then
        mode="niri"
      fi
      echo "$mode" > ${cfg.modeFile}
      echo "m920q: current-mode resynced to $mode after deploy" >&2
    '';
  in {
    systemd.services.m920q-mode-switch = {
      description = "Apply M920q manual mode switch (headless <-> niri)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = modeSwitchScript;
        TimeoutStartSec = cfg.modeSwitchTimeoutSec;
      };
    };

    # Records the base toplevel path so mode-switch can switch back to headless
    # even when /run/current-system currently points at the niri leaf. Runs only
    # in the base (headless) config; the niri leaf must not overwrite it.
    system.activationScripts.m920q-base-toplevel = lib.mkIf (!config.hostConfig.isGui) (lib.stringAfter ["specialfs"] ''
      echo "$systemConfig" > ${cfg.baseToplevelFile}
    '');

    # After a deploy the base config re-activates but the mode-switch never re-runs,
    # leaving /run/m920q-current-mode stale (observed: current-mode=niri while the box
    # boots headless). Reconcile the marker with the hardware reality so a later
    # manual switch starts from an accurate baseline. Only runs when the marker
    # already exists: a fresh boot (/run tmpfs) has no stale state.
    system.activationScripts.m920q-resync-mode = lib.mkIf (!config.hostConfig.isGui) (lib.stringAfter ["m920q-base-toplevel"] ''
      if [[ -f ${cfg.modeFile} ]]; then
        ${hdmiResyncScript}
      fi
    '');
  });
}
