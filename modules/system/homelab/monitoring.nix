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
    fritzbox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Monitor a Fritz!Box router via the fritz exporter (scrape job,
          WAN-down alert rule, and fritzbox/password secret). Disable on
          hosts without a Fritz!Box on the LAN.
        '';
      };
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
      exporters.fritz = mkIf cfg.fritzbox.enable {
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
        # One static_config per service so each probe carries an "app" label:
        # the relabeling below sets instance to the probed URL, which contains
        # no service name, so alert rules must select by label instead of
        # matching on the URL.
        #
        # Immich >=3.x moved server-info endpoints under /api/server;
        # /api/server/ping is its unauthenticated liveness check. (Immich 3.x
        # also serves app metrics on a dedicated port, not /metrics on this
        # one — the HTTP probe is the only Immich signal scraped here.)
        blackboxProbes =
          lib.optionals config.modules.system.homelab.immich.enable [
            {
              targets = ["http://127.0.0.1:${toString config.modules.system.homelab.immich.port}/api/server/ping"];
              labels.app = "immich";
            }
          ]
          ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
            {
              targets = ["http://127.0.0.1:${toString config.modules.system.homelab.nextcloud.port}/status.php"];
              labels.app = "nextcloud";
            }
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
        ]
        ++ lib.optionals cfg.fritzbox.enable [
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
            static_configs = blackboxProbes;
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
        #
        # ntfy receives Grafana's webhook as publish-as-JSON: a raw
        # alertmanager payload POSTed to ntfy fails to parse as a publish
        # message and is delivered as an unnamed file attachment without
        # title or priority. The custom payload template renders proper
        # title/message/priority/tags instead. It must produce valid JSON on
        # every render; interpolated text is limited to repo-constant
        # descriptions and alert labels.
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
                    url = "http://127.0.0.1:2586/";
                    httpMethod = "POST";
                    payload = {
                      # Rendered output must be valid ntfy publish-as-JSON on
                      # a SINGLE line: raw newlines inside a JSON string are
                      # rejected by ntfy, and YAML folding escapes them into
                      # literal backslash-n.
                      #
                      # No Go-template variables ($p := ...) here: Grafana's
                      # provisioning interpolator strips bare $identifier
                      # tokens from provisioned payloads before storing them,
                      # which corrupts the template until it fails to parse
                      # at send time. Priority is therefore status-based
                      # rather than severity-based. Descriptions are repo
                      # constants (no user input), so skipping JSON escaping
                      # is safe — Grafana's alert templates have no
                      # jsonEscape function anyway.
                      template = ''
                        {"topic":"homelab-alerts","tags":[{{ if eq .Status "resolved" }}"white_check_mark"{{ else }}"warning","rotating_light"{{ end }}],"priority":{{ if eq .Status "resolved" }}2{{ else }}4{{ end }},"title":"[{{ .Status | toUpper }}:{{ len .Alerts }}] {{ range .Alerts }}{{ .Labels.alertname }} {{ end }}","message":"{{ range .Alerts }}- {{ .Labels.alertname }}{{ with .Annotations.description }}: {{ . }}{{ end }}{{ with .Labels.instance }} ({{ . }}){{ end }} | {{ end }}Manage: {{ .ExternalURL }}"}
                      '';
                    };
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
              # Empty group_by consolidates all simultaneous alerts (e.g. an
              # outage taking down several exporters) into a single
              # notification listing every affected rule.
              group_by = [];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
        };

        # Prometheus alert rules evaluated by Grafana unified alerting and
        # routed to ntfy through the contact point and notification policy
        # above.
        #
        # Queries use the "<metric> == bool <threshold>" pattern instead of a
        # plain filter: boolean comparisons always return a series (1 when
        # triggered, 0 when healthy), while filtered comparisons return an
        # empty vector on healthy systems, which the count/threshold chain
        # would report as NoData and page falsely. Genuinely missing data
        # (Prometheus unreachable) stays meaningful and fires via noDataState.
        alerting.rules.settings = lib.mkIf cfg.alerting.enable {
          apiVersion = 1;
          groups = let
            mkAlert = uid: severity: title: description: expr: {
              inherit uid title;
              condition = "C";
              "for" = "2m";
              # Missing data means the monitored thing is unobservable, which
              # for down-detection is itself an alert; evaluation errors keep
              # the last state instead of paging (visible in the Grafana UI).
              noDataState = "Alerting";
              execErrState = "KeepLast";
              labels.severity = severity;
              annotations.description = description;
              data = [
                {
                  refId = "A";
                  relativeTimeRange.from = 600;
                  relativeTimeRange.to = 0;
                  # Scalar datasourceUid is load-bearing: the provisioner does
                  # not round-trip the datasource object form into the DB, and
                  # evaluation then fails with "uid is empty".
                  datasourceUid = "prometheus";
                  model = {
                    inherit expr;
                    datasource.type = "prometheus";
                    datasource.uid = "prometheus";
                    instant = true;
                    intervalMs = 1000;
                    maxDataPoints = 43200;
                    refId = "A";
                  };
                }
                {
                  # Legacy datasourceUid here (not a datasource object): the
                  # expression engine rejects __expr__ nodes that look like
                  # data queries (it then demands a relative time range).
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
                    ''probe_success{job="blackbox",app="nextcloud"} == bool 0'')
                ])
                ++ (lib.optionals config.modules.system.homelab.immich.enable [
                  (mkAlert "immich-down" "urgent" "ImmichDown"
                    "Immich is not responding to HTTP health probes"
                    ''probe_success{job="blackbox",app="immich"} == bool 0'')
                ])
                ++ (lib.optionals config.modules.system.homelab.adguardhome.enable [
                  (mkAlert "adguard-down" "urgent" "AdGuardDown"
                    "AdGuard Home DNS server is not responding"
                    ''up{job="adguard"} == bool 0 or adguard_running == bool 0'')
                ])
                ++ (lib.optionals config.modules.system.homelab.backup.enable [
                  (mkAlert "backup-failed" "high" "BackupFailed"
                    "A ZFS snapshot or replication job (sanoid/syncoid) ended in failed state; backups are incomplete until fixed"
                    ''node_systemd_unit_state{name=~".*(sanoid|syncoid).*[.]service",state="failed"} == bool 1'')
                ])
                ++ (lib.optionals cfg.fritzbox.enable [
                  (mkAlert "fritzbox-wan-down" "urgent" "FritzboxWanDown"
                    "Fritz!Box WAN physical link is down"
                    "fritz_wan_phys_link_status == bool 0")
                ])
                ++ [
                  (mkAlert "node-exporter-down" "urgent" "NodeExporterDown"
                    "Node exporter is unreachable (system metrics unavailable)"
                    ''up{job="node"} == bool 0'')
                  (mkAlert "postgres-down" "high" "PostgresDown"
                    "PostgreSQL exporter is unreachable"
                    ''up{job="postgres"} == bool 0'')
                ];
            }
          ];
        };
      };
    };

    sops.secrets =
      {
        "grafana/admin-password".owner = "grafana";
        "grafana/secret-key".owner = "grafana";
      }
      // lib.optionalAttrs cfg.fritzbox.enable {
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
