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
      # Resolves through AdGuard, the LAN resolver, over plain UDP. A SERVFAIL
      # or timeout here is what LAN clients experience.
      dns_udp:
        prober: dns
        timeout: 5s
        dns:
          query_name: example.com
          query_type: A
          preferred_ip_protocol: ip4
          valid_rcodes:
            - NOERROR
      # Raw WAN reachability and RTT, catching link loss and bufferbloat that
      # starve DNS before any service starts failing.
      icmp_wan:
        prober: icmp
        timeout: 5s
        icmp:
          preferred_ip_protocol: ip4
  '';

  # Blackbox probes carry the probed endpoint as the scrape target; these
  # relabels move it to __param_target, record it as instance, and point the
  # actual scrape at the local blackbox exporter. Shared by the HTTP, DNS and
  # ICMP jobs.
  blackboxRelabel = [
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
        # zfs/diskstats collectors do not expose per-pool free space or
        # determinate-nixd GC activity; the health-check (maintenance.nix)
        # writes those as Prometheus textfile metrics into this directory.
        extraFlags = [
          "--collector.textfile.directory=/var/lib/node-exporter/textfile"
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
          config.modules.system.homelab.immich.enable
          || config.modules.system.homelab.nextcloud.enable
          || config.modules.system.homelab.jellyfin.enable;
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
          ]
          ++ lib.optionals config.modules.system.homelab.jellyfin.enable [
            {
              # /health returns 200 once the server is up, independent of auth.
              targets = ["http://127.0.0.1:8096/health"];
              labels.app = "jellyfin";
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
                targets = [
                  "127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}"
                ];
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
                targets = [
                  "127.0.0.1:${toString config.services.prometheus.exporters.fritz.port}"
                ];
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
                targets = [
                  "127.0.0.1:${toString config.services.prometheus.exporters.nextcloud.port}"
                ];
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
            relabel_configs = blackboxRelabel;
          }
        ]
        ++ lib.optionals config.modules.system.homelab.adguardhome.enable [
          {
            job_name = "blackbox-dns";
            scrape_interval = "30s";
            metrics_path = "/probe";
            params.module = ["dns_udp"];
            static_configs = [
              {
                targets = ["127.0.0.1:53"];
                labels.probe = "adguard-dns";
              }
            ];
            relabel_configs = blackboxRelabel;
          }
        ]
        ++ lib.optionals cfg.fritzbox.enable [
          {
            job_name = "blackbox-icmp";
            scrape_interval = "30s";
            metrics_path = "/probe";
            params.module = ["icmp_wan"];
            static_configs = [
              {
                targets = ["1.1.1.1"];
                labels.probe = "wan";
              }
            ];
            relabel_configs = blackboxRelabel;
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

    # Postgres is only deployed as Nextcloud's database backend; scrape the
    # exporter (and alert on it) only when that stack exists.
    services.prometheus.exporters.postgres = mkIf config.modules.system.homelab.nextcloud.enable {
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
        datasources.settings.datasources =
          [
            {
              name = "Prometheus";
              type = "prometheus";
              uid = "prometheus";
              url = "http://127.0.0.1:${toString cfg.prometheusPort}";
              isDefault = true;
            }
            # Garmin health metrics (InfluxDB 1.x, InfluxQL). Only present when
            # the garmin module is enabled; uid matches the dashboard JSON.
          ]
          ++ lib.optionals config.modules.system.homelab.garmin.enable [
            {
              name = "Garmin-InfluxDB";
              type = "influxdb";
              uid = "garmin_influxdb";
              url = "http://127.0.0.1:${toString config.modules.system.homelab.garmin.influxPort}";
              isDefault = false;
              # Top-level user (v1 datasource model), same account garmin.nix
              # creates with CREATE USER. Without it Grafana sends only the
              # password and InfluxDB rejects every query with
              # "unable to parse authentication credentials".
              user = "garmin";
              jsonData = {
                dbName = "GarminStats";
                httpMode = "GET";
              };
              secureJsonData.password = "$__file{${config.sops.secrets."garmin/influx-user-password".path}}";
            }
          ];

        dashboards.settings.providers =
          [
            {
              name = "fritz";
              type = "file";
              disableDeletion = true;
              options.path = ./fritz-dashboard.json;
            }
          ]
          ++ lib.optionals config.modules.system.homelab.garmin.enable [
            {
              name = "garmin";
              type = "file";
              disableDeletion = true;
              options.path = ./garmin-dashboard.json;
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
            # Down-style alerts use noDataState "Alerting" (default): missing
            # data means the monitored thing is unobservable and must page.
            # Decision-data metrics (e.g. NixdGcStorm) set "OK" instead: their
            # series legitimately does not exist until the first post-deploy
            # health-check publishes it, and treating that gap as an incident
            # paged every evaluation until data arrived (2026-09-16, false
            # NixdGcStorm right after switch).
            mkAlert = uid: severity: title: description: expr: noDataState: {
              inherit uid title;
              condition = "C";
              "for" = "2m";
              # Missing data means the monitored thing is unobservable, which
              # for down-detection is itself an alert; evaluation errors keep
              # the last state instead of paging (visible in the Grafana UI).
              inherit noDataState;
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
                    ''probe_success{job="blackbox",app="nextcloud"} == bool 0'' "Alerting")
                ])
                ++ (lib.optionals config.modules.system.homelab.immich.enable [
                  (mkAlert "immich-down" "urgent" "ImmichDown"
                    "Immich is not responding to HTTP health probes"
                    ''probe_success{job="blackbox",app="immich"} == bool 0'' "Alerting")
                ])
                ++ (lib.optionals config.modules.system.homelab.jellyfin.enable [
                  (mkAlert "jellyfin-down" "urgent" "JellyfinDown"
                    "Jellyfin is not responding to HTTP health probes"
                    ''probe_success{job="blackbox",app="jellyfin"} == bool 0'' "Alerting")
                ])
                ++ (lib.optionals config.modules.system.homelab.adguardhome.enable [
                  (mkAlert "adguard-down" "urgent" "AdGuardDown"
                    "AdGuard Home DNS server is not responding"
                    ''up{job="adguard"} == bool 0 or adguard_running == bool 0'' "Alerting")
                ])
                ++ (lib.optionals config.modules.system.homelab.backup.enable [
                  (mkAlert "backup-failed" "high" "BackupFailed"
                    "A ZFS snapshot or replication job (sanoid/syncoid) ended in failed state; backups are incomplete until fixed"
                    ''node_systemd_unit_state{name=~".*(sanoid|syncoid).*[.]service",state="failed"} == bool 1'' "Alerting")
                ])
                ++ (lib.optionals cfg.fritzbox.enable [
                  (mkAlert "fritzbox-wan-down" "urgent" "FritzboxWanDown"
                    "Fritz!Box WAN physical link is down"
                    "fritz_wan_phys_link_status == bool 0" "Alerting")
                ])
                ++ (lib.optionals config.modules.system.homelab.adguardhome.enable [
                  (mkAlert "dns-resolution-failed" "urgent" "DnsResolutionFailed"
                    "AdGuard Home is not resolving queries; LAN name resolution is failing"
                    ''probe_success{job="blackbox-dns"} == bool 0'' "Alerting")
                ])
                ++ (lib.optionals cfg.fritzbox.enable [
                  (mkAlert "wan-unreachable" "urgent" "WanUnreachable"
                    "Public internet is unreachable over ICMP (uplink down or dropping packets)"
                    ''probe_success{job="blackbox-icmp"} == bool 0'' "Alerting")
                  (mkAlert "wan-high-latency" "high" "WanHighLatency"
                    "ICMP round-trip to the public internet exceeds 500 ms (bufferbloat starving DNS)"
                    ''probe_duration_seconds{job="blackbox-icmp"} > bool 0.5'' "Alerting")
                ])
                ++ [
                  (mkAlert "node-exporter-down" "urgent" "NodeExporterDown"
                    "Node exporter is unreachable (system metrics unavailable)"
                    ''up{job="node"} == bool 0'' "Alerting")
                ]
                ++ lib.optionals config.modules.system.maintenance.enable [
                  # Feedstock for the managed-GC strategy decision
                  # (2026-09-16 audit): determinate-nixd trims the store
                  # whenever pool free space is inside its 5-20 % band, and
                  # under rpool pressure it ran every ~2 h overnight. A
                  # sustained storm means the strategy (or the storage
                  # layout) must be decided; this rule measures the cadence.
                  # Decision metric: absent data (pre-first-run deploy gap) is
                  # not an incident; only a sustained storm is.
                  (mkAlert "nixd-gc-storm" "high" "NixdGcStorm"
                    "determinate-nixd managed GC ran more than 3 times in 90 minutes"
                    ''nixd_gc_runs_last_90min > bool 3'' "OK")
                ]
                ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
                  (mkAlert "postgres-down" "high" "PostgresDown"
                    "PostgreSQL exporter is unreachable"
                    ''up{job="postgres"} == bool 0'' "Alerting")
                  (mkAlert "filesystem-full" "urgent" "FilesystemFull"
                    "A persistent filesystem is under 10% free. On ZFS all datasets of a pool share free space, so any runaway writer can zero all of them (2026-09 m920q incident)"
                    ''(node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"}) < bool 0.1'' "Alerting")
                  # Early warning ahead of the urgent FilesystemFull rule: a
                  # pool approaching 20% free (the upper bound of the
                  # managed-GC steady band) pages high-severity before a
                  # writer has already made the filesystem slow and
                  # GC-heavy at 10%.
                  (mkAlert "filesystem-warning" "high" "FilesystemWarn"
                    "A persistent filesystem is under 20% free; runaway writes head toward FilesystemFull"
                    ''(node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"}) < bool 0.2'' "Alerting")
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
      }
      // lib.optionalAttrs config.modules.system.homelab.garmin.enable {
        # Grafana reads the InfluxDB user password via $__file{}.
        "garmin/influx-user-password".owner = "grafana";
      }
      // lib.optionalAttrs config.modules.system.homelab.garmin.calendar.enable {
        # Bearer token the calendar-sync script uses against the annotation API.
        "grafana/calendar-annotation-token".owner = "garmin-fetch";
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
      # No readiness gate on Prometheus: upstream Grafana provisions
      # datasources lazily (on first query), so a Prometheus outage must not
      # hold Grafana down in a boot restart loop.
      serviceConfig = {
        EnvironmentFile = config.sops.templates."grafana-env".path;
        RestartSec = "5s";
      };
    };

    users.groups.netdev = {};

    # Textfile metrics (written by the maintenance health-check) live on /per
    # so GC-cadence history survives reboots.
    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/node-exporter/textfile";
        user = "node-exporter";
        group = "node-exporter";
        mode = "0755";
      }
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
