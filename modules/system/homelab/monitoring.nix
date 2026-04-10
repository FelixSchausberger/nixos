{
  config,
  lib,
  ...
}: {
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

  config = lib.mkIf config.modules.system.homelab.monitoring.enable {
    services.prometheus = {
      enable = true;
      port = config.modules.system.homelab.monitoring.prometheusPort;
      listenAddress = "127.0.0.1";
      retentionTime = "30d";

      exporters.node = {
        enable = true;
        port = config.modules.system.homelab.monitoring.nodeExporterPort;
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
              targets = ["127.0.0.1:${toString config.modules.system.homelab.monitoring.nodeExporterPort}"];
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
          http_port = config.modules.system.homelab.monitoring.grafanaPort;
          domain = "m920q";
        };
        security = {
          admin_user = "admin";
          # Admin password set via $GF_SECURITY_ADMIN_PASSWORD env var from sops
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString config.modules.system.homelab.monitoring.prometheusPort}";
            isDefault = true;
          }
        ];
      };
    };

    # Inject Grafana admin password from sops secret
    sops.secrets."grafana/admin-password" = {
      owner = "grafana";
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.secrets."grafana/admin-password".path;

    environment.persistence."/per".directories = [
      "/var/lib/grafana"
      "/var/lib/prometheus2"
    ];

    networking.firewall.allowedTCPPorts = [
      config.modules.system.homelab.monitoring.grafanaPort
    ];
  };
}
