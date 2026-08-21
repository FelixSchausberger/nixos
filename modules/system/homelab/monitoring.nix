{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.monitoring;
  inherit (lib) mkIf;

  blackboxConfig = pkgs.writeText "blackbox.yml" ''
    modules:
      http_2xx:
        prober: http
        http:
          valid_status_codes:
            - 200
            - 302
            - 401
          follow_redirects: true
  '';
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
    alerting = {
      enable = lib.mkEnableOption "Grafana alert rules and notification channel to ntfy";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.grafanaPort != cfg.prometheusPort;
        message = "Grafana and Prometheus must use different ports";
      }
      {
        assertion = cfg.grafanaPort != cfg.nodeExporterPort;
        message = "Grafana and node_exporter must use different ports";
      }
      {
        assertion = cfg.prometheusPort != cfg.nodeExporterPort;
        message = "Prometheus and node_exporter must use different ports";
      }
      {
        assertion =
          !config.modules.system.homelab.adguardhome.enable
          || cfg.grafanaPort != config.modules.system.homelab.adguardhome.port;
        message = "When AdGuard Home is enabled, Grafana port must differ from AdGuard admin port";
      }
    ];

    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      listenAddress = "127.0.0.1";
      retentionTime = "14d";

      extraFlags = [
        "--storage.tsdb.wal-compression"
      ];

      globalConfig = {
        scrape_interval = "30s";
      };

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
          "hwmon"
          "thermal_zone"
        ];
      };
      exporters.fritz = {
        enable = true;
        port = 9787;
        listenAddress = "127.0.0.1";
        settings.devices = [
          {
            name = "Fritz!Box 4050";
            # Direct LAN IP — more reliable than fritz.box DNS
            hostname = "192.168.178.1";
            username = "prometheus";
            password_file = config.sops.secrets."fritzbox/password".path;
          }
        ];
      };

      scrapeConfigs = let
        hasAppTargets =
          config.modules.system.homelab.immich.enable || config.modules.system.homelab.nextcloud.enable;
        blackboxTargets =
          lib.optionals config.modules.system.homelab.immich.enable [
            "http://127.0.0.1:${toString config.modules.system.homelab.immich.port}/api/server-info/version"
          ]
          ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
            "http://127.0.0.1:${toString config.modules.system.homelab.nextcloud.port}/status.php"
          ];
      in
        [
          {
            job_name = "node";
            scrape_interval = "30s";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString cfg.nodeExporterPort}"];
              }
            ];
          }
          {
            job_name = "postgres";
            scrape_interval = "30s";
            static_configs = [
              {
                targets = ["127.0.0.1:9187"];
              }
            ];
          }
          {
            job_name = "fritz";
            scrape_interval = "60s";
            # Fritz!Box TR-064 queries are slow; 60s prevents overloading the device
            scrape_timeout = "45s";
            static_configs = [
              {
                targets = ["127.0.0.1:9787"];
              }
            ];
          }
        ]
        ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
          {
            job_name = "nextcloud-exporter";
            scrape_interval = "60s";
            static_configs = [
              {
                targets = ["127.0.0.1:9205"];
              }
            ];
          }
        ]
        ++ lib.optionals config.modules.system.homelab.immich.enable [
          {
            job_name = "immich";
            scrape_interval = "60s";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString config.modules.system.homelab.immich.port}"];
              }
            ];
            metrics_path = "/metrics";
          }
        ]
        ++ lib.optionals config.modules.system.homelab.adguardhome.enable [
          {
            job_name = "adguard";
            scrape_interval = "60s";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString config.modules.system.homelab.adguardhome.exporterPort}"];
              }
            ];
            metrics_path = "/metrics";
          }
        ]
        ++ lib.optionals hasAppTargets [
          {
            job_name = "blackbox";
            scrape_interval = "60s";
            metrics_path = "/probe";
            params.module = ["http_2xx"];
            static_configs = [{targets = blackboxTargets;}];
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ];
    };

    services.prometheus.exporters.nextcloud = mkIf config.modules.system.homelab.nextcloud.enable {
      enable = true;
      url = "http://127.0.0.1:${toString config.modules.system.homelab.nextcloud.port}";
      username = "admin";
      passwordFile = config.sops.secrets."nextcloud/admin-password".path;
    };
    users.users.nextcloud-exporter = mkIf config.modules.system.homelab.nextcloud.enable {
      extraGroups = ["nextcloud"];
    };

    services.prometheus.exporters.blackbox = {
      enable = true;
      configFile = blackboxConfig;
    };

    services.prometheus.exporters.postgres = {
      enable = true;
      runAsLocalSuperUser = true;
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
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
          secret_key = "$__file{${config.sops.secrets."grafana/secret-key".path}}";
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            isDefault = true;
          }
        ];

        dashboards.settings.providers = [
          {
            name = "fritz";
            type = "file";
            disableDeletion = true;
            options.path = ./fritz-dashboard.json;
          }
        ];

        # Grafana alerting contact point and notification policy
        alerting.contactPoints.settings = lib.mkIf cfg.alerting.enable {
          apiVersion = 1;
          contactPoints = [
            {
              name = "ntfy";
              receivers = [
                {
                  uid = "ntfy-webhook";
                  type = "webhook";
                  settings = {
                    url = "http://127.0.0.1:2586/homelab-alerts";
                    httpMethod = "POST";
                    autoResolve = true;
                    uploadImage = false;
                  };
                  disableResolveMessage = false;
                }
              ];
            }
          ];
        };

        alerting.policies.settings = lib.mkIf cfg.alerting.enable {
          apiVersion = 1;
          policies = [
            {
              receiver = "ntfy";
              group_by = [
                "alertname"
                "severity"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
        };

        # Prometheus alert rules evaluated by Grafana unified alerting and
        # routed to ntfy through the contact point and notification policy
        # above. Fire semantics mirror the previous poller ("query returns any
        # row"): A runs the instant query, B counts rows, C fires when > 0.
        alerting.rules.settings = lib.mkIf cfg.alerting.enable {
          apiVersion = 1;
          groups = let
            mkAlert = uid: severity: title: description: expr: {
              inherit uid title;
              condition = "C";
              "for" = "2m";
              labels.severity = severity;
              annotations.description = description;
              data = [
                {
                  refId = "A";
                  relativeTimeRange.from = 600;
                  relativeTimeRange.to = 0;
                  datasourceUid = "prometheus";
                  model = {
                    inherit expr;
                    instant = true;
                    intervalMs = 1000;
                    maxDataPoints = 43200;
                    refId = "A";
                  };
                }
                {
                  refId = "B";
                  datasourceUid = "__expr__";
                  model = {
                    datasource.type = "__expr__";
                    datasource.uid = "__expr__";
                    type = "reduce";
                    expression = "A";
                    reducer = "count";
                    intervalMs = 1000;
                    maxDataPoints = 43200;
                    refId = "B";
                  };
                }
                {
                  refId = "C";
                  datasourceUid = "__expr__";
                  model = {
                    datasource.type = "__expr__";
                    datasource.uid = "__expr__";
                    type = "threshold";
                    expression = "B";
                    conditions = [
                      {
                        evaluator.params = [0];
                        evaluator.type = "gt";
                        operator.type = "and";
                        query.params = ["A"];
                      }
                    ];
                    intervalMs = 1000;
                    maxDataPoints = 43200;
                    refId = "C";
                  };
                }
              ];
            };
          in [
            {
              name = "homelab";
              folder = "Homelab";
              interval = "2m";
              rules =
                (lib.optionals config.modules.system.homelab.nextcloud.enable [
                  (mkAlert "nextcloud-down" "urgent" "NextcloudDown"
                    "Nextcloud is not responding to HTTP health probes"
                    ''probe_success{job="blackbox",instance=~".*nextcloud.*"} == 0'')
                ])
                ++ (lib.optionals config.modules.system.homelab.immich.enable [
                  (mkAlert "immich-down" "urgent" "ImmichDown"
                    "Immich is not responding to HTTP health probes"
                    ''probe_success{job="blackbox",instance=~".*immich.*"} == 0'')
                ])
                ++ (lib.optionals config.modules.system.homelab.adguardhome.enable [
                  (mkAlert "adguard-down" "urgent" "AdGuardDown"
                    "AdGuard Home DNS server is not responding"
                    ''up{job="adguard"} == 0 or adguard_running == 0'')
                ])
                ++ [
                  (mkAlert "fritzbox-wan-down" "urgent" "FritzboxWanDown"
                    "Fritz!Box WAN connection is down (uptime = 0)"
                    "fritz_upnp_uptime_seconds == 0")
                  (mkAlert "node-exporter-down" "urgent" "NodeExporterDown"
                    "Node exporter is unreachable (system metrics unavailable)"
                    ''up{job="node"} == 0'')
                  (mkAlert "postgres-down" "high" "PostgresDown"
                    "PostgreSQL exporter is unreachable"
                    ''up{job="postgres"} == 0'')
                ];
            }
          ];
        };
      };
    };

    sops.secrets = {
      "grafana/admin-password".owner = "grafana";
      "grafana/secret-key".owner = "grafana";
      "fritzbox/password".owner = "fritz-exporter";
    };
    sops.templates."grafana-env" = {
      content = "GF_SECURITY_ADMIN_PASSWORD=${config.sops.placeholder."grafana/admin-password"}";
      owner = "grafana";
    };

    systemd.services.grafana = {
      after = [
        "sops-nix.service"
        "prometheus.service"
      ];
      wants = ["prometheus.service"];
      unitConfig = {
        StartLimitBurst = 10;
        StartLimitIntervalSec = 60;
      };
      serviceConfig = {
        EnvironmentFile = config.sops.templates."grafana-env".path;
        RestartSec = "5s";
        ExecStartPre = [
          "+${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.prometheusPort}/-/healthy > /dev/null 2>&1; do sleep 2; done'"
        ];
      };
    };

    users.groups.netdev = {};

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
      cfg.grafanaPort
    ];
  };
}
