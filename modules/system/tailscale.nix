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
    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether Tailscale may manage DNS on this host (MagicDNS, split DNS,
        global nameservers). Disable on hosts whose connectivity must not
        depend on tailnet DNS resolvers (e.g. work machines).
      '';
    };
    openSSH = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Tailscale SSH: tailscaled intercepts port 22 from tailnet
        clients and authenticates by device identity (tailnet ACLs), while
        regular sshd keeps handling non-tailnet connections.
      '';
    };
    udpGROInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Network interface to apply UDP GRO forwarding fix for Tailscale throughput";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.udpGROInterface == null || cfg.udpGROInterface != "";
        message = "modules.system.homelab.tailscale.udpGROInterface must be null or a non-empty interface name";
      }
    ];

    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile;
      openFirewall = true;
      # Tailscale SSH has no dedicated upstream option; `tailscale set --ssh`
      # (via the tailscaled-set oneshot) enables it for already-registered
      # nodes without needing authKeyFile.
      extraSetFlags = lib.optionals cfg.openSSH ["--ssh"];
      # Enables IP forwarding sysctls and correct rpfilter rules for subnet routing.
      # rpfilter fix prevents asymmetric routes from dropping subnet-routed packets.
      useRoutingFeatures = lib.mkIf (cfg.advertiseRoutes != [] || cfg.exitNode) "server";
      extraUpFlags =
        lib.optionals cfg.exitNode ["--advertise-exit-node"]
        ++ lib.optionals (cfg.advertiseRoutes != []) [
          "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
        ]
        ++ lib.optionals (!cfg.acceptDns) ["--accept-dns=false"];
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
