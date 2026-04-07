{
  config,
  lib,
  ...
}: {
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
  };

  config = lib.mkIf config.modules.system.homelab.tailscale.enable {
    services.tailscale = {
      enable = true;
      inherit (config.modules.system.homelab.tailscale) authKeyFile;
      openFirewall = true;
      extraUpFlags =
        lib.optionals config.modules.system.homelab.tailscale.exitNode ["--advertise-exit-node"]
        ++ lib.optionals (config.modules.system.homelab.tailscale.advertiseRoutes != []) [
          "--advertise-routes=${lib.concatStringsSep "," config.modules.system.homelab.tailscale.advertiseRoutes}"
        ];
    };

    # Allow all traffic on the Tailscale interface
    networking.firewall.trustedInterfaces = ["tailscale0"];

    environment.persistence."/per".directories = [
      "/var/lib/tailscale"
    ];
  };
}
