# On-demand graphical session.
#
# For hosts that keep the GUI stack in the base closure (so no NixOS
# specialisation switch is needed) but do not want a display manager running
# the session at boot — e.g. a homelab server that only needs a desktop when a
# projector is hotplugged. The session is a normal systemd user service, started
# and stopped by a DRM-hotplug udev rule. Seat access comes from seatd because
# there is no logind login session.
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

  # Same wrapper the display manager would run (niri-session starts niri.service
  # and brings up niri-session.target, which the home modules bind to).
  sessionCommand =
    if hasNiri
    then "${config.programs.niri.package}/bin/niri-session"
    else null;
in {
  options.modules.system.sessionOnDemand = {
    enable = lib.mkEnableOption "start the graphical session on demand when a display is hotplugged";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = sessionCommand != null;
        message = "modules.system.sessionOnDemand currently supports niri in hostConfig.wms";
      }
    ];

    # No login session exists, so the compositor gets DRM access from seatd.
    services.seatd.enable = true;
    users.users.${user}.extraGroups = [config.services.seatd.group "video" "render" "input"];

    # Long-running session. No [Install]/WantedBy: it is only ever started by the
    # hotplug handler below, never at boot.
    systemd.user.services.niri-on-demand = {
      description = "Niri session (on demand)";
      serviceConfig = {
        Type = "simple";
        ExecStart = sessionCommand;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    systemd.services.display-hotplug = {
      description = "Start or stop the on-demand session on DRM hotplug";
      serviceConfig = {
        Type = "oneshot";
        # Must outlive the debounce sleep in the stop path.
        TimeoutStartSec = "120s";
        ExecStart = pkgs.writeShellScript "display-hotplug" ''
          if grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
            exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start niri-on-demand.service
          fi
          # Projector warm-up bounces HPD (~68s on m920q), which would kill a
          # healthy session if acted on from a single read. Re-read the CURRENT
          # state after the window instead of trusting the triggering event: a
          # reconnect during it keeps the session, a genuine loss stops it. The
          # stop criterion is the negation of start -- unused connectors always
          # read "disconnected", so a positive "connected" match keeps it alive.
          sleep 45
          if ! grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
            exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop niri-on-demand.service
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
            ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start niri-on-demand.service
          fi
        '';
      };
    };

    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${pkgs.systemd}/bin/systemctl start --no-block display-hotplug.service"
    '';
  };
}
