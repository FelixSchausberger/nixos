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
          # Hardware sensors: CPU temps, fan speeds via ACPI/hwmon
          "hwmon"
          "thermal_zone"
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
          # Admin password injected via EnvironmentFile from sops secret
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
          # Secret key must be set explicitly since NixOS 26.05 removed the default
          secret_key = "$__file{${config.sops.secrets."grafana/secret-key".path}}";
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

    sops.secrets."grafana/admin-password" = {
      owner = "grafana";
    };
    sops.secrets."grafana/secret-key" = {
      owner = "grafana";
    };

    # sops.templates generates a KEY=VALUE file; raw secret files cannot be used as EnvironmentFile
    sops.templates."grafana-env" = {
      content = "GF_SECURITY_ADMIN_PASSWORD=${config.sops.placeholder."grafana/admin-password"}";
      owner = "grafana";
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.templates."grafana-env".path;

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/grafana";
        user = "grafana";
        group = "grafana";
        mode = "0700";
      }
      {
        directory = "/var/lib/prometheus2";
        user = "prometheus";
        group = "prometheus";
        mode = "0700";
      }
    ];

    networking.firewall.allowedTCPPorts = [
      config.modules.system.homelab.monitoring.grafanaPort
    ];
  };
}
