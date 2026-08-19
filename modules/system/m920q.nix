# M920q HDMI mode switching: headless <-> niri specialisation state machine.
# Shared between the real host (hosts/m920q) and VM integration tests.
# Guards with lib.mkIf (!config.hostConfig.isGui) for activation scripts
# so the niri specialisation leaf does not overwrite base-toplevel state.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.m920q;
in {
  options.modules.system.m920q = {
    enable = lib.mkEnableOption "M920q HDMI mode switching helpers";

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
      default = "/run/m920q-hdmi-state";
      description = "Path to the HDMI state file written by hdmi-detect";
    };

    baseToplevelFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/m920q-base-toplevel";
      description = "Path to the base-toplevel marker (records niri-carrying toplevel)";
    };

    retryCountFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/m920q-retry-count";
      description = "Path to the bounded retry counter file";
    };

    timerDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Debounce delay (seconds) before the mode-switch fires";
    };

    modeSwitchTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "Timeout for the mode-switch service (switch-to-configuration can be slow)";
    };
  };

  config = lib.mkIf cfg.enable (let
    inherit (cfg) user;

    hdmiDetectScript = pkgs.writeShellScript "m920q-hdmi-detect" ''
      set -euo pipefail

      hdmi_status_files=(/sys/class/drm/*-HDMI-A-*/status)
      if (( ''${#hdmi_status_files[@]} == 0 )); then
        exit 0
      fi

      if grep -qsx "connected" "''${hdmi_status_files[@]}"; then
        new_state="niri"
      else
        new_state="headless"
      fi

      # Only restart the debounced mode-switch timer when the hardware state
      # actually changed; a plain detect run must not re-trigger a switch.
      old_state=$(cat ${cfg.stateFile} 2>/dev/null || echo "unknown")
      if [[ "$old_state" != "$new_state" ]]; then
        echo "$new_state" > ${cfg.stateFile}
        exec /run/current-system/sw/bin/systemctl restart m920q-mode-switch.timer
      fi
    '';

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
      mode_file=${cfg.modeFile}
      state_file=${cfg.stateFile}

      timeout 30 ${pkgs.bash}/bin/bash -c 'until /run/current-system/sw/bin/nix-daemon --version >/dev/null 2>&1; do sleep 0.5; done' 2>/dev/null || true

      if [[ ! -f "$state_file" ]]; then
        exit 0
      fi

      desired_mode=$(cat "$state_file")

      current_mode=""
      if [[ -f "$mode_file" ]]; then
        current_mode=$(cat "$mode_file")
      fi

      if [[ "$current_mode" == "$desired_mode" ]]; then
        exit 0
      fi

      # Re-verify live HDMI hardware before committing the switch; the state file
      # may be stale if a detect run raced with a previous activation.
      hdmi_status_files=(/sys/class/drm/*-HDMI-A-*/status)
      actual_mode="headless"
      if (( ''${#hdmi_status_files[@]} > 0 )) && grep -qsx "connected" "''${hdmi_status_files[@]}"; then
        actual_mode="niri"
      fi

      if [[ "$actual_mode" != "$desired_mode" ]]; then
        echo "$actual_mode" > "$state_file"
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

      # The inner switch-to-configuration runs are best-effort: a partial failure
      # (e.g. busy user mounts) must not abort the whole script with set -e, which
      # previously left /run/m920q-current-mode stale.
      switch_ok=1
      if [[ "$desired_mode" == "niri" ]]; then
        if ! "$gui_switch" test; then
          echo "WARNING: GUI switch failed; keeping current mode and retrying later" >&2
          switch_ok=0
        else
          /run/current-system/sw/bin/systemctl stop greetd.service 2>/dev/null || true
          /run/current-system/sw/bin/systemctl restart "$hm_service"
          # Poll instead of --wait: systemctl --wait hangs after switch-to-configuration
          # changes the system underneath the running process in QEMU VM environments.
          for _ in $(seq 1 30); do
            /run/current-system/sw/bin/systemctl is-active "$hm_service" >/dev/null 2>&1 && break
            sleep 0.5
          done
          /run/current-system/sw/bin/systemctl start greetd.service
        fi
      else
        if ! "$headless_switch" test; then
          echo "WARNING: headless switch failed; keeping current mode and retrying later" >&2
          switch_ok=0
        else
          /run/current-system/sw/bin/systemctl stop graphical.target greetd.service 2>/dev/null || true
          /run/current-system/sw/bin/systemctl restart "$hm_service"
        fi
      fi

      # Always keep the marker consistent with what the system is actually running.
      # On success that is desired_mode; on failure the system is still in the
      # previous mode, so the marker is left untouched and a retry is scheduled.
      if [[ $switch_ok -eq 1 ]]; then
        echo "$desired_mode" > "$mode_file"
        rm -f ${cfg.retryCountFile}
      else
        echo "WARNING: mode switch to $desired_mode failed; current-mode stays $current_mode ($mode_file)" >&2

        # Bounded retry: restart the debounced timer so the switch is attempted
        # again shortly, but give up after several failures to avoid a hot loop.
        retries=0
        [[ -f ${cfg.retryCountFile} ]] && retries=$(cat ${cfg.retryCountFile})
        if [[ $retries -lt 5 ]]; then
          echo $((retries + 1)) > ${cfg.retryCountFile}
          /run/current-system/sw/bin/systemctl restart m920q-mode-switch.timer || true
        else
          echo "WARNING: giving up after 5 failed mode-switch attempts; next HDMI change will retry" >&2
          rm -f ${cfg.retryCountFile}
        fi
      fi

      # Re-evaluate after the (slow) switch: if hardware state changed while the
      # lock was held, schedule a corrective switch once the lock is released.
      hdmi_status_files=(/sys/class/drm/*-HDMI-A-*/status)
      actual_mode="headless"
      if (( ''${#hdmi_status_files[@]} > 0 )) && grep -qsx "connected" "''${hdmi_status_files[@]}"; then
        actual_mode="niri"
      fi

      if [[ "$actual_mode" != "$desired_mode" ]]; then
        echo "$actual_mode" > "$state_file"
        /run/current-system/sw/bin/systemctl restart m920q-mode-switch.timer || true
      fi
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
    systemd.services.m920q-hdmi-detect = {
      description = "Detect HDMI hotplug and update mode state";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = hdmiDetectScript;
      };
    };

    systemd.services.m920q-mode-switch = {
      description = "Switch M920q mode from HDMI hotplug (debounced)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = modeSwitchScript;
        TimeoutStartSec = cfg.modeSwitchTimeoutSec;
      };
    };

    systemd.timers.m920q-mode-switch = {
      description = "Debounced M920q mode switch after HDMI hotplug";
      wantedBy = ["multi-user.target"];
      timerConfig = {
        OnActiveSec = cfg.timerDelaySec;
        AccuracySec = "5s";
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
    # boots headless). Reconcile the marker with the hardware reality so a later HDMI
    # change triggers the correct switch. Only runs when the marker already exists: a
    # fresh boot (/run tmpfs) has no stale state, and pre-seeding "niri" would suppress
    # the debounced boot-time HDMI switch (desired == current → no-op).
    system.activationScripts.m920q-resync-mode = lib.mkIf (!config.hostConfig.isGui) (lib.stringAfter ["m920q-base-toplevel"] ''
      if [[ -f ${cfg.modeFile} ]]; then
        ${hdmiResyncScript}
      fi
    '');

    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${pkgs.systemd}/bin/systemctl start m920q-hdmi-detect.service"
    '';
  });
}
