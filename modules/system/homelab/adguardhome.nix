{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.adguardhome;
in {
  options.modules.system.homelab.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS ad-blocker";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for DNS (53 TCP/UDP) and admin UI";
    };
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "AdGuard Home admin username";
    };
  };

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;
      inherit (cfg) openFirewall;
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

    sops.secrets."adguardhome/admin-password" = {owner = "root";};

    systemd.services.adguardhome-setpasswd = {
      description = "Configure AdGuard Home admin credentials from sops secret";
      wantedBy = ["multi-user.target"];
      after = ["adguardhome.service"];
      requires = ["adguardhome.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "adguardhome-setpasswd" ''
          password=$(cat ${config.sops.secrets."adguardhome/admin-password".path})
          # POST to the setup wizard endpoint — no-op (returns 400) if already configured
          ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:3000/control/install/configure \
            -H "Content-Type: application/json" \
            -d "{\"web\":{\"ip\":\"0.0.0.0\",\"port\":3000},\"dns\":{\"ip\":\"0.0.0.0\",\"port\":53},\"username\":\"${cfg.adminUser}\",\"password\":\"$password\"}" \
            || true
        '';
      };
    };

    environment.persistence."/per".directories = [
      "/var/lib/AdGuardHome"
    ];
  };
}
