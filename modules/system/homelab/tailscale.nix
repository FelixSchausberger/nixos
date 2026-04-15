{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.tailscale;
in {
  options.modules.system.homelab.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to sops-decrypted Tailscale auth key for automated login";
    };
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Subnet routes to advertise (e.g. [\"192.168.1.0/24\"])";
    };
    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Advertise this host as a Tailscale exit node";
    };
    udpGROInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Network interface to apply UDP GRO forwarding fix for Tailscale throughput";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile;
      openFirewall = true;
      extraUpFlags =
        lib.optionals cfg.exitNode ["--advertise-exit-node"]
        ++ lib.optionals (cfg.advertiseRoutes != []) [
          "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
        ];
    };

    # Required for subnet routing and exit node functionality
    boot.kernel.sysctl = lib.mkIf (cfg.advertiseRoutes != [] || cfg.exitNode) {
      "net.ipv6.conf.all.forwarding" = true;
    };

    # Improves UDP forwarding throughput for Tailscale when interface is specified
    systemd.services.tailscale-udp-gro-fix = lib.mkIf (cfg.udpGROInterface != null) {
      description = "Apply UDP GRO forwarding settings for Tailscale on ${cfg.udpGROInterface}";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -K ${cfg.udpGROInterface} rx-udp-gro-forwarding on rx-gro-list off";
      };
    };

    # Allow all traffic on the Tailscale interface
    networking.firewall.trustedInterfaces = ["tailscale0"];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/tailscale";
        user = "root";
        group = "root";
        mode = "0750";
      }
    ];
  };
}
