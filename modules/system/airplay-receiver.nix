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
  hotplug = import ./display-hotplug.nix {inherit pkgs;};

  # UxPlay's default timestamp sync stalls the first mirror from a client
  # whose AirPlay clock is not wall-clock; see the option description.
  vsyncFlag = lib.optionalString (!cfg.timestampSync) "-vsync no ";

  # The on-demand session starts with the projector, but WirePlumber
  # enumerates the HDMI sink asynchronously after the DRM hotplug. UxPlay's
  # pulsesink follows the default sink when the audio stream is created, and
  # WirePlumber's configured default is the analog front jack. Select the
  # HDMI sink first and keep the configured default when no HDMI output
  # exists (projector off, or a display whose EDID carries no audio).
  preferHdmiSink = pkgs.writeShellScript "uxplay-prefer-hdmi-sink" ''
    set -u
    pactl=${pkgs.pulseaudio}/bin/pactl
    attempts=20
    while [ "$attempts" -gt 0 ]; do
      sink=$("$pactl" list short sinks 2>/dev/null | ${pkgs.gnugrep}/bin/grep -m1 hdmi | ${pkgs.coreutils}/bin/cut -f2 || true)
      if [ -n "$sink" ]; then
        "$pactl" set-default-sink "$sink"
        echo "selected HDMI sink $sink"
        exit 0
      fi
      attempts=$((attempts - 1))
      ${pkgs.coreutils}/bin/sleep 0.5
    done
    echo "no HDMI sink found; keeping the configured default sink"
  '';
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

    timestampSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use the AirPlay client's timestamps for A/V synchronization (UxPlay
        -vsync, its default). Disable it for clients whose AirPlay
        timestamps are not wall-clock: the first mirror after the client has
        been idle stalls on its first frame until the receiver is
        reconnected. Without timestamps the receiver stops dropping late
        frames, at the cost of timestamp-based lip-sync correction.
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
        # nixpkgs defaults disable both general and user-service publishing;
        # AirPlay discovery needs service registration plus address records.
        settings.publish = {
          disable-publishing = false;
          disable-user-service-publishing = false;
          publish-addresses = true;
        };
      };

      # Avoid dual mDNS responder warning when systemd-resolved has mDNS enabled.
      services.resolved.settings.Resolve.MulticastDNS = false;

      environment.systemPackages = [pkgs.uxplay];

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
        # Comin deploys main automatically, so a package change would otherwise
        # restart the receiver and drop an active client mid-cast. The udev
        # hotplug cycle starts the new binary on the next display connect.
        restartIfChanged = false;
        serviceConfig = {
          # stdbuf forces line buffering: uxplay's stdout is block-buffered
          # under journald, so startup logs otherwise only appear (all stamped
          # at exit time) when the process terminates.
          # -p pins uxplay to the legacy AirPlay ports; without it uxplay binds
          # random ephemeral ports each run, so clients discover the service
          # via mDNS but fail to connect through the fixed-port firewall rules
          # declared above.
          ExecStartPre = "${preferHdmiSink}";
          ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.uxplay}/bin/uxplay -p ${vsyncFlag}-vs kmssink -as pulsesink -n Projector -nh";
          StandardOutput = "journal";
          StandardError = "journal";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # udev runs as root; reach the lingering user manager via machined.
      systemd.services.uxplay-hotplug = {
        description = "Start/stop UxPlay AirPlay receiver on HDMI hotplug";
        serviceConfig = {
          Type = "oneshot";
          # Debounce must outlive the sleep in the stop path; explicit rather
          # than relying on defaults that vary between systemd releases.
          TimeoutStartSec = "120s";
          ExecStart = pkgs.writeShellScript "uxplay-hotplug" (hotplug.hotplugScript {
            inherit (cfg) user;
            startUnit = "uxplay.service";
            stopUnit = "uxplay.service";
          });
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
        # Comin deploys main automatically, so a package change would otherwise
        # restart the receiver and drop an active client mid-cast. The session
        # restarts it (with the new binary) on the next projector hotplug.
        restartIfChanged = false;
        serviceConfig = {
          # -p keeps uxplay on the legacy AirPlay ports declared in the
          # firewall rules above; see the headless service for details.
          ExecStartPre = "${preferHdmiSink}";
          ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.uxplay}/bin/uxplay -p ${vsyncFlag}-vs \"waylandsink fullscreen=true\" -as pulsesink -n Projector -nh";
          StandardOutput = "journal";
          StandardError = "journal";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })
  ]);
}
