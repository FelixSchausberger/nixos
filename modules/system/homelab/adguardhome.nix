{
  config,
  lib,
  ...
}: {
  options.modules.system.homelab.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS ad-blocker";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for DNS (53 TCP/UDP) and admin UI";
    };
  };

  config = lib.mkIf config.modules.system.homelab.adguardhome.enable {
    services.adguardhome = {
      enable = true;
      inherit (config.modules.system.homelab.adguardhome) openFirewall;
      settings = {
        # Admin UI port — migrate to 80/443 via Caddy after initial setup
        http.address = "0.0.0.0:3000";
        dns = {
          upstream_dns = [
            "https://dns.cloudflare.com/dns-query"
            "https://dns.quad9.net/dns-query"
          ];
          bootstrap_dns = ["9.9.9.9" "1.1.1.1"];
          bind_hosts = ["0.0.0.0"];
          port = 53;
        };
      };
    };

    environment.persistence."/per".directories = [
      "/var/lib/AdGuardHome"
    ];
  };
}
