{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.monitoring;
in {
  options.modules.system.homelab.monitoring = {
    enable = lib.mkEnableOption "Prometheus + node_exporter + Grafana monitoring stack";
    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Grafana HTTP port (default 3001 to avoid conflict with AdGuard Home on 3000)";
    };
    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Prometheus HTTP port (localhost only)";
    };
    nodeExporterPort = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "Node exporter metrics port (localhost only)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      listenAddress = "127.0.0.1";
      retentionTime = "30d";

      exporters.node = {
        enable = true;
        port = cfg.nodeExporterPort;
        enabledCollectors = [
          "systemd"
          "processes"
          "filesystem"
          "diskstats"
          "netdev"
          "meminfo"
          "loadavg"
          "zfs"
        ];
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString cfg.nodeExporterPort}"];
            }
          ];
        }
      ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = cfg.grafanaPort;
          domain = "m920q";
        };
        security = {
          admin_user = "admin";
          # Credentials injected via EnvironmentFile from sops template
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
          secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            isDefault = true;
          }
        ];
      };
    };

    sops.secrets."grafana/admin-password" = {owner = "grafana";};
    sops.secrets."grafana/secret-key" = {owner = "grafana";};

    # Combine both secrets into a single env file for Grafana's serviceConfig
    sops.templates."grafana-env" = {
      owner = "grafana";
      content = ''
        GF_SECURITY_ADMIN_PASSWORD=${config.sops.placeholder."grafana/admin-password"}
        GF_SECURITY_SECRET_KEY=${config.sops.placeholder."grafana/secret-key"}
      '';
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.templates."grafana-env".path;

    environment.persistence."/per".directories = [
      "/var/lib/grafana"
      "/var/lib/prometheus2"
    ];

    networking.firewall.allowedTCPPorts = [cfg.grafanaPort];
  };
}
