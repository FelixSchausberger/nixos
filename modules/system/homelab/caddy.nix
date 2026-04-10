{
  config,
  lib,
  ...
}: {
  options.modules.system.homelab.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy with automatic HTTPS";
    immichDomain = lib.mkOption {
      type = lib.types.str;
      default = "CHANGEME.immich";
      description = "Domain for Immich (e.g. immich.example.com). Caddy obtains Let's Encrypt cert automatically.";
    };
    grafanaDomain = lib.mkOption {
      type = lib.types.str;
      default = "CHANGEME.grafana";
      description = "Domain for Grafana (e.g. grafana.example.com).";
    };
    adguardDomain = lib.mkOption {
      type = lib.types.str;
      default = "CHANGEME.adguard";
      description = "Domain for AdGuard Home admin UI (e.g. adguard.example.com).";
    };
  };

  config = lib.mkIf config.modules.system.homelab.caddy.enable {
    services.caddy = {
      enable = true;
      virtualHosts = {
        ${config.modules.system.homelab.caddy.immichDomain}.extraConfig = ''
          reverse_proxy localhost:${toString config.modules.system.homelab.immich.port}
          # Immich requires large upload support for video files
          request_body {
            max_size 50GB
          }
        '';
        ${config.modules.system.homelab.caddy.grafanaDomain}.extraConfig = ''
          reverse_proxy localhost:${toString config.modules.system.homelab.monitoring.grafanaPort}
        '';
        ${config.modules.system.homelab.caddy.adguardDomain}.extraConfig = ''
          reverse_proxy localhost:3000
        '';
      };
    };

    environment.persistence."/per".directories = [
      "/var/lib/caddy"
    ];

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
