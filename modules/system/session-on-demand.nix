# On-demand graphical session.
#
# For hosts that keep the GUI stack in the base closure (so no NixOS
# specialisation switch is needed) but do not want a display manager running
# the session at boot — e.g. a homelab server that only needs a desktop when a
# projector is hotplugged. The compositor runs as its standard niri systemd
# unit, started and stopped by a DRM-hotplug udev rule. Seat access comes from
# seatd because there is no logind login session.
{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  cfg = config.modules.system.sessionOnDemand;
  inherit (hostConfig) user;
  hasNiri = builtins.elem "niri" (hostConfig.wms or []);
in {
  options.modules.system.sessionOnDemand = {
    enable = lib.mkEnableOption "start the graphical session on demand when a display is hotplugged";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hasNiri;
        message = "modules.system.sessionOnDemand currently supports niri in hostConfig.wms";
      }
    ];

    # No login session exists, so the compositor gets DRM access from seatd.
    services.seatd.enable = true;
    users.users.${user} = {
      extraGroups = [config.services.seatd.group "video" "render" "input"];
      # The hotplug handlers reach the user manager with `systemctl --user -M`,
      # which requires it to be running outside a login session.
      linger = true;
    };

    # Start niri.service, not a bespoke wrapper around niri-session.
    # niri.service is the unit that pulls in graphical-session.target
    # (BindsTo) and, through it, niri-session.target, which the home modules
    # bind to. Running niri-session as a systemd user service takes its
    # direct-execution path and never activates that target chain. Scoped to
    # hosts that enable this module.
    systemd.user.services.niri.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };

    systemd.services.display-hotplug = {
      description = "Start or stop the on-demand session on DRM hotplug";
      serviceConfig = {
        Type = "oneshot";
        # Must outlive the debounce sleep in the stop path.
        TimeoutStartSec = "120s";
        ExecStart = pkgs.writeShellScript "display-hotplug" ''
          # HDMI-A is matched deliberately: the vkms virtual connector is
          # permanently "connected" and would otherwise keep the session up.
          if grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
            exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start niri.service
          fi
          # Projector warm-up bounces HPD (~68s on m920q), which would kill a
          # healthy session if acted on from a single read. Re-read the CURRENT
          # state after the window instead of trusting the triggering event: a
          # reconnect during it keeps the session, a genuine loss stops it. The
          # stop criterion is the negation of start -- unused connectors always
          # read "disconnected", so a positive "connected" match keeps it alive.
          sleep 45
          if ! grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
            # Stopping graphical-session.target tears down niri.service, the
            # session target, and every unit bound to them.
            exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop graphical-session.target
          fi
        '';
      };
    };

    # A connector already present at boot may not emit a HOTPLUG change event,
    # so start the session once at boot when a display is connected. Only the
    # start path: a disconnect is still handled by the debounced hotplug unit.
    systemd.services.session-on-demand-boot = {
      description = "Start the on-demand session if a display is present at boot";
      wantedBy = ["multi-user.target"];
      after = ["systemd-user-sessions.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "session-on-demand-boot" ''
          if grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
            ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start niri.service
          fi
        '';
      };
    };

    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${pkgs.systemd}/bin/systemctl start --no-block display-hotplug.service"
    '';
  };
}
