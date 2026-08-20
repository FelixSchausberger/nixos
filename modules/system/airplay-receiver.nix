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
  };

  config = lib.mkIf cfg.enable {
    # mDNS/Bonjour discovery for AirPlay targets on the local network.
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

    systemd.user.services.uxplay = {
      description = "UxPlay AirPlay receiver";
      # niri-session.target activates after niri.service is ready and exports
      # WAYLAND_DISPLAY; graphical-session.target alone fires too early.
      after = ["niri-session.target"];
      partOf = ["niri-session.target"];
      bindsTo = ["niri-session.target"];
      wantedBy = ["niri-session.target"];
      serviceConfig = {
        ExecStart = "${pkgs.uxplay}/bin/uxplay -vs \"waylandsink fullscreen=true\" -as pulsesink -n Projector -nh";
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
