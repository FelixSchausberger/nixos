{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.homelab.rustdesk = {
    enable = lib.mkEnableOption "RustDesk self-hosted relay server";
    relayPort = lib.mkOption {
      type = lib.types.port;
      default = 21117;
      description = "RustDesk relay (hbbr) port";
    };
    signalPort = lib.mkOption {
      type = lib.types.port;
      default = 21115;
      description = "RustDesk signal (hbbs) port";
    };
    relayAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Externally-reachable address advertised by hbbs to clients for relay connections.
        Must be an IP or hostname that remote clients can reach (e.g. Tailscale IP).
        When empty, hbbs advertises no relay and clients must have it pre-configured.
      '';
    };
  };

  config = lib.mkIf config.modules.system.homelab.rustdesk.enable {
    users.users.rustdesk = {
      isSystemUser = true;
      group = "rustdesk";
      home = "/var/lib/rustdesk";
    };
    users.groups.rustdesk = {};

    systemd.tmpfiles.rules = [
      "d /var/lib/rustdesk 0700 rustdesk rustdesk -"
    ];

    # Relay server (hbbr): handles desktop stream relay
    systemd.services.rustdesk-relay = {
      description = "RustDesk relay server (hbbr)";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        ExecStart = "${pkgs.rustdesk-server}/bin/hbbr";
        WorkingDirectory = "/var/lib/rustdesk";
        User = "rustdesk";
        Group = "rustdesk";
        Restart = "always";
        RestartSec = "5s";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/lib/rustdesk"];
        NoNewPrivileges = true;
      };
    };

    # Signal/rendezvous server (hbbs): handles client pairing
    systemd.services.rustdesk-signal = {
      description = "RustDesk signal server (hbbs)";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        ExecStart =
          "${pkgs.rustdesk-server}/bin/hbbs"
          + lib.optionalString (config.modules.system.homelab.rustdesk.relayAddress != "") " -r ${config.modules.system.homelab.rustdesk.relayAddress}";
        WorkingDirectory = "/var/lib/rustdesk";
        User = "rustdesk";
        Group = "rustdesk";
        Restart = "always";
        RestartSec = "5s";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/lib/rustdesk"];
        NoNewPrivileges = true;
      };
    };

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/rustdesk";
        user = "rustdesk";
        group = "rustdesk";
        mode = "0700";
      }
    ];

    networking.firewall.allowedTCPPorts = [
      config.modules.system.homelab.rustdesk.signalPort # 21115 hbbs
      (config.modules.system.homelab.rustdesk.signalPort + 1) # 21116 hbbs websocket
      config.modules.system.homelab.rustdesk.relayPort # 21117 hbbr
      (config.modules.system.homelab.rustdesk.relayPort + 1) # 21118 hbbr websocket
    ];
    networking.firewall.allowedUDPPorts = [
      (config.modules.system.homelab.rustdesk.signalPort + 1) # 21116 UDP
    ];
  };
}
