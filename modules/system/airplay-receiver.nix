# AirPlay receiver (UxPlay + Avahi) with two mutually exclusive modes:
#
# - headless: uxplay renders straight to the DRM connector via kmssink —
#   no compositor, no greetd, no session required. A udev rule starts it on
#   HDMI hotplug and stops it when the display goes away. Requires the user
#   manager to be up (linger) so pulsesink can reach PipeWire.
# - gui: uxplay renders into the compositor via waylandsink and is bound to
#   niri-session.target (which guarantees WAYLAND_DISPLAY is exported).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.airplayReceiver;
in {
  options.modules.system.airplayReceiver = {
    enable = lib.mkEnableOption "AirPlay receiver support (UxPlay + Avahi)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "schausberger";
      description = "User owning the uxplay systemd user service";
    };

    mode = lib.mkOption {
      type = lib.types.enum ["headless" "gui"];
      default = "headless";
      description = ''
        headless: kmssink direct-to-DRM rendering started by HDMI hotplug.
        gui: waylandsink inside the compositor session.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # mDNS/Bonjour discovery for AirPlay targets on the local network.
    {
      services.avahi = {
        enable = true;
        openFirewall = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          userServices = true;
        };
      };

      # Avoid dual mDNS responder warning when systemd-resolved has mDNS enabled.
      services.resolved.settings.Resolve.MulticastDNS = false;

      environment.systemPackages = with pkgs; [
        uxplay
      ];

      networking.firewall = {
        allowedTCPPorts = [
          7000
          7001
          7100
        ];
        allowedUDPPorts = [
          6000
          6001
          7011
        ];
      };
    }

    (lib.mkIf (cfg.mode == "headless") {
      # kmssink becomes DRM master directly; only valid while no compositor
      # is running (mutually exclusive with the gui mode by construction).
      systemd.user.services.uxplay = {
        description = "UxPlay AirPlay receiver";
        serviceConfig = {
          # stdbuf forces line buffering: uxplay's stdout is block-buffered
          # under journald, so startup logs otherwise only appear (all stamped
          # at exit time) when the process terminates.
          # -p pins uxplay to the legacy AirPlay ports; without it uxplay binds
          # random ephemeral ports each run, so clients discover the service
          # via mDNS but fail to connect through the fixed-port firewall rules
          # declared above.
          ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.uxplay}/bin/uxplay -p -vs kmssink -as pulsesink -n Projector -nh";
          StandardOutput = "journal";
          StandardError = "journal";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # udev runs as root; reach the lingering user manager via machined.
      # Start is immediate on connect; stop is debounced below because a
      # single sysfs read cannot distinguish a real unplug from an HPD flap.
      systemd.services.uxplay-hotplug = {
        description = "Start/stop UxPlay AirPlay receiver on HDMI hotplug";
        serviceConfig = {
          Type = "oneshot";
          # Debounce must outlive the sleep in the stop path; explicit rather
          # than relying on defaults that vary between systemd releases.
          TimeoutStartSec = "120s";
          ExecStart = pkgs.writeShellScript "uxplay-hotplug" ''
            if grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
              exec ${pkgs.systemd}/bin/systemctl --user -M ${cfg.user}@ start uxplay.service
            fi
            # Projector warm-up bounces HPD (~68s after connect on m920q),
            # which killed healthy sessions when acting on a single read.
            # Re-read CURRENT state after the window instead of trusting the
            # triggering event: a reconnect during it leaves the session up,
            # a genuine loss stops it. The stop criterion is the negation of
            # start -- unused connectors always read "disconnected", so any
            # positive "connected" match must keep the session alive.
            sleep 45
            if ! grep -qsx connected /sys/class/drm/*-HDMI-A-*/status; then
              exec ${pkgs.systemd}/bin/systemctl --user -M ${cfg.user}@ stop uxplay.service
            fi
          '';
        };
      };

      services.udev.extraRules = ''
        ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${pkgs.systemd}/bin/systemctl start --no-block uxplay-hotplug.service"
      '';
    })

    (lib.mkIf (cfg.mode == "gui") {
      # niri-session.target activates after niri.service is ready and exports
      # WAYLAND_DISPLAY; graphical-session.target alone fires too early.
      systemd.user.services.uxplay = {
        description = "UxPlay AirPlay receiver";
        after = ["niri-session.target"];
        partOf = ["niri-session.target"];
        bindsTo = ["niri-session.target"];
        wantedBy = ["niri-session.target"];
        serviceConfig = {
          # -p keeps uxplay on the legacy AirPlay ports declared in the
          # firewall rules above; see the headless service for details.
          ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.uxplay}/bin/uxplay -p -vs \"waylandsink fullscreen=true\" -as pulsesink -n Projector -nh";
          StandardOutput = "journal";
          StandardError = "journal";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })
  ]);
}
