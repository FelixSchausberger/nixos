{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.monitoring;
  hl = config.modules.system.homelab;
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

  # Probes carry the probed endpoint as the scrape target; these relabels move
  # it to __param_target, record it as instance, and point the actual scrape
  # at the local prober exporter (blackbox 9115, json 7979). Shared by the
  # HTTP, DNS, ICMP and wall-power jobs.
  proberRelabel = port: [
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
      replacement = "127.0.0.1:${toString port}";
    }
  ];

  hasWallPlugs = cfg.wallPower.plugs != {};

  # The alerting host's own name. Every scrape job carries it as a `host`
  # label so alert rules, notification titles and the local ntfy topic all
  # name the source machine; the one remote job (node-desktop) overrides it.
  localHost = config.networking.hostName;

  # Prometheus alert rules: evaluated by the local Prometheus and routed by
  # Alertmanager to alertmanager-ntfy, which reads the ntfy priority verbatim
  # from `alert.labels.priority`. `for = 2m` matches the former Grafana rule
  # cadence. Annotations are Prometheus-templated, so `summary` names the host
  # and `description` can quote the offending mountpoint or value.
  mkRule = name: priority: summary: description: expr: {
    alert = name;
    inherit expr;
    "for" = "2m";
    labels.priority = priority;
    annotations = {
      summary = "${summary} on {{ $labels.host }}";
      inherit description;
    };
  };

  # tmpfs/overlay-style pseudo-filesystems never warrant a capacity page; the
  # size floor drops small non-ZFS boot partitions. A 511 MiB vfat ESP on the
  # desktop read as under 10% free and paged the ZFS-oriented rule (2026-10),
  # which was never the rule's intent.
  fsFstype = ''fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"'';
  fsSize = "node_filesystem_size_bytes{${fsFstype}}";
  fsAvail = "node_filesystem_avail_bytes{${fsFstype}}";

  alertRuleGroups =
    (lib.optionals config.modules.system.homelab.nextcloud.enable [
      (mkRule "NextcloudDown" "urgent" "Nextcloud is down"
        "Nextcloud is not answering HTTP health probes ({{ $labels.instance }})"
        ''probe_success{job="blackbox",app="nextcloud"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.immich.enable [
      (mkRule "ImmichDown" "urgent" "Immich is down"
        "Immich is not answering HTTP health probes ({{ $labels.instance }})"
        ''probe_success{job="blackbox",app="immich"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.jellyfin.enable [
      (mkRule "JellyfinDown" "urgent" "Jellyfin is down"
        "Jellyfin is not answering HTTP health probes ({{ $labels.instance }})"
        ''probe_success{job="blackbox",app="jellyfin"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.navidrome.enable [
      (mkRule "NavidromeDown" "urgent" "Navidrome is down"
        "Navidrome is not answering HTTP health probes ({{ $labels.instance }})"
        ''probe_success{job="blackbox",app="navidrome"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.vaultwarden.enable [
      (mkRule "VaultwardenDown" "urgent" "Vaultwarden is down"
        "Vaultwarden is not answering HTTP health probes ({{ $labels.instance }})"
        ''probe_success{job="blackbox",app="vaultwarden"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.adguardhome.enable [
      (mkRule "AdGuardDown" "urgent" "AdGuard Home DNS is down"
        "AdGuard Home is not responding"
        ''up{job="adguard"} == 0 or adguard_running == 0'')
      (mkRule "DnsResolutionFailed" "urgent" "LAN DNS resolution is failing"
        "AdGuard Home is not resolving queries; LAN name resolution is failing"
        ''probe_success{job="blackbox-dns"} == 0'')
    ])
    ++ (lib.optionals config.modules.system.homelab.backup.enable [
      (mkRule "BackupFailed" "high" "A backup job failed"
        "A ZFS snapshot or replication job (sanoid/syncoid) ended in failed state; backups are incomplete until fixed"
        ''node_systemd_unit_state{name=~".*(sanoid|syncoid).*[.]service",state="failed"} == 1'')
    ])
    ++ (lib.optionals cfg.fritzbox.enable [
      (mkRule "FritzboxWanDown" "urgent" "Fritz!Box WAN link is down"
        "Fritz!Box WAN physical link is down"
        "fritz_wan_phys_link_status == 0")
      (mkRule "WanUnreachable" "urgent" "Public internet is unreachable"
        "Public internet is unreachable over ICMP (uplink down or dropping packets)"
        ''probe_success{job="blackbox-icmp"} == 0'')
      (mkRule "WanHighLatency" "high" "WAN latency is high"
        "ICMP round-trip to the public internet exceeds 500 ms (bufferbloat starving DNS)"
        ''probe_duration_seconds{job="blackbox-icmp"} > 0.5'')
    ])
    ++ [
      (mkRule "NodeExporterDown" "urgent" "Node exporter is unreachable"
        "Node exporter is unreachable; system metrics are unavailable"
        ''up{job="node"} == 0'')
      (mkRule "FilesystemFull" "urgent" "Filesystem nearly full"
        "Persistent filesystem {{ $labels.mountpoint }} ({{ $labels.device }}) is at {{ $value | humanizePercentage }} free"
        ''(${fsAvail} / ${fsSize}) < 0.1 and ${fsSize} > 2e9'')
      (mkRule "FilesystemWarn" "high" "Filesystem low on free space"
        "Persistent filesystem {{ $labels.mountpoint }} ({{ $labels.device }}) is at {{ $value | humanizePercentage }} free; runaway writes head toward FilesystemFull"
        ''(${fsAvail} / ${fsSize}) < 0.2 and ${fsSize} > 2e9'')
    ]
    ++ lib.optionals config.modules.system.maintenance.enable [
      # Tripwire for the disabled managed collector: garbageCollector.strategy
      # is "disabled" (sops-common), so determinate-nixd must never trim the
      # store on its own. An absent series (pre-first-run deploy gap) does not
      # fire; only a sustained storm does.
      (mkRule "NixdGcStorm" "high" "determinate-nixd GC storm"
        "determinate-nixd managed GC ran more than 3 times in 90 minutes"
        "nixd_gc_runs_last_90min > 3")
    ]
    ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
      (mkRule "PostgresDown" "high" "PostgreSQL exporter is unreachable"
        "PostgreSQL exporter is unreachable"
        ''up{job="postgres"} == 0'')
    ];

  homelabGroups = [
    {
      name = "homelab";
      rules = alertRuleGroups;
    }
  ];

  # Wall-power measurement: the Shelly plug meters the whole machine at the
  # outlet over local HTTP RPC (no cloud). apower is the instantaneous WALL
  # draw in watts, aenergy.total the cumulative Wh counter — both are wall
  # power by definition; CPU/GPU series come from the node exporter and must
  # never be labelled as system power.
  shellyConfig = pkgs.writeText "json-exporter-shelly.yml" ''
    modules:
      default:
        metrics:
          - name: wall_power_watts
            type: gauge
            help: Wall power metered by the Shelly plug (instantaneous)
            path: '{ .apower }'
          - name: wall_energy_wh_total
            type: counter
            help: Cumulative wall energy counter of the Shelly plug since power-on (Wh)
            path: '{ .aenergy.total }'
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
    prometheusHttpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8446;
      description = "Tailscale Serve HTTPS port terminating TLS for the Prometheus UI";
    };
    nodeExporterPort = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "Node exporter metrics port (localhost only)";
    };
    alerting = {
      enable = lib.mkEnableOption "Prometheus alert rules delivered through Alertmanager and alertmanager-ntfy";
      ruleGroups = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [];
        description = ''
          Generated Prometheus alert rule groups. The same value is serialized
          into services.prometheus.rules; it is exposed here so the monitoring
          test can assert rule integrity structurally instead of parsing the
          rendered YAML.
        '';
      };
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
    wallPower = {
      plugs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {
          m920q = "192.168.178.21";
          desktop = "192.168.178.22";
        };
        description = ''
          Shelly wall-power plugs to scrape through the json exporter, as
          name to LAN-IP pairs (DHCP-reserved in the Fritz!Box, cloud disabled).
          Feeds the wall-power side of the power benchmark; CPU/GPU series
          stay with the node exporter. Empty until the plugs are provisioned,
          which disables the json exporter and the wall-power job entirely.
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
      {
        assertion =
          cfg.prometheusHttpsPort
          != hl.zellijWeb.httpsPort
          && cfg.prometheusHttpsPort != hl.opencodeWeb.httpsPort
          && cfg.prometheusHttpsPort != hl.homepage.httpsPort;
        message = "modules.system.homelab.monitoring.prometheusHttpsPort must differ from the zellij-web, opencode-web and homepage Tailscale Serve ports";
      }
    ];

    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      listenAddress = "127.0.0.1";
      retentionTime = "14d";

      extraFlags =
        [
          "--storage.tsdb.wal-compression"
        ]
        # external-url carries no path prefix ("/"), so handlers stay
        # exactly where they are: loopback probes, the Grafana datasource
        # and the Homepage widget keep hitting /api/v1 and /-/healthy
        # directly. Only link generation changes - the UI's / -> /query
        # redirect gains the https Serve URL, because a plain-http redirect
        # to a Serve port is answered with 400.
        ++ lib.optional hl.caddyProxy.enable "--web.external-url=https://${hl.caddyProxy.tailnetDomain}:${toString cfg.prometheusHttpsPort}/";

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
      # Local JSON scraping for the Shelly wall-power plugs (apower /
      # aenergy.total over LAN RPC). Only runs once plugs are configured.
      exporters.json = mkIf hasWallPlugs {
        enable = true;
        port = 7979;
        configFile = shellyConfig;
      };

      scrapeConfigs = let
        hasAppTargets =
          config.modules.system.homelab.immich.enable
          || config.modules.system.homelab.nextcloud.enable
          || config.modules.system.homelab.jellyfin.enable
          || config.modules.system.homelab.navidrome.enable
          || config.modules.system.homelab.vaultwarden.enable;
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
              labels.host = localHost;
            }
          ]
          ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
            {
              targets = ["http://127.0.0.1:${toString config.modules.system.homelab.nextcloud.port}/status.php"];
              labels.app = "nextcloud";
              labels.host = localHost;
            }
          ]
          ++ lib.optionals config.modules.system.homelab.jellyfin.enable [
            {
              # /health returns 200 once the server is up, independent of auth.
              targets = ["http://127.0.0.1:8096/health"];
              labels.app = "jellyfin";
              labels.host = localHost;
            }
          ]
          ++ lib.optionals config.modules.system.homelab.navidrome.enable [
            {
              # ping.view answers 200 without credentials, and the prefixed
              # path pins the BaseURL that Subsonic clients must be
              # configured with (an unprefixed /rest 302s into the SPA and
              # looks like an outage on the phone).
              targets = [
                "http://127.0.0.1:${toString config.modules.system.homelab.navidrome.port}/navidrome/rest/ping.view"
              ];
              labels.app = "navidrome";
              labels.host = localHost;
            }
          ]
          ++ lib.optionals config.modules.system.homelab.vaultwarden.enable [
            {
              # /alive is the unauthenticated liveness endpoint; probed on the
              # Rocket loopback port, not through the Tailscale Serve front.
              targets = ["http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}/alive"];
              labels.app = "vaultwarden";
              labels.host = localHost;
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
                labels.host = localHost;
              }
            ];
          }
          {
            # The desktop host's node exporter over the LAN. A separate job
            # from "node" on purpose: the desktop is regularly powered off, and
            # NodeExporterDown selects job="node" — an intentional off is not
            # an incident and must not page.
            job_name = "node-desktop";
            scrape_interval = "30s";
            static_configs = [
              {
                targets = ["${inputs.self.lib.hosts.desktop.ip}:9100"];
                labels.host = "desktop";
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
                labels.host = localHost;
              }
            ];
          }
        ]
        ++ lib.optionals (config.services.vitals.enable or false) [
          {
            # vitals-daemon runs as a per-user service on loopback with no
            # NixOS option to move its port (default 8080, from its own
            # config.toml), so the address is pinned here. Scraped only where
            # the daemon is enabled; Prometheus reaches the user daemon over
            # loopback regardless of which user manager owns it.
            job_name = "vitals";
            scrape_interval = "30s";
            static_configs = [
              {
                targets = ["127.0.0.1:8080"];
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
                labels.host = localHost;
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
                labels.host = localHost;
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
                labels.host = localHost;
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
            relabel_configs = proberRelabel 9115;
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
                labels.host = localHost;
              }
            ];
            relabel_configs = proberRelabel 9115;
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
                labels.host = localHost;
              }
            ];
            relabel_configs = proberRelabel 9115;
          }
        ]
        ++ lib.optionals hasWallPlugs [
          {
            # Shelly plugs over local HTTP RPC: the probe target is the full
            # endpoint URL, fetched by the json exporter through the prober
            # relabels above. The "plug" label names the measured machine
            # (name from the wallPower.plugs attribute).
            job_name = "wall-power";
            scrape_interval = "30s";
            metrics_path = "/probe";
            static_configs =
              lib.mapAttrsToList (name: ip: {
                targets = ["http://${ip}/rpc/Switch.GetStatus?id=0"];
                labels.plug = name;
                labels.host = localHost;
              })
              cfg.wallPower.plugs;
            relabel_configs = proberRelabel config.services.prometheus.exporters.json.port;
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

    # RAPL energy counters ship 0400 root-only (CVE-2020-8694) while the node
    # exporter runs unprivileged; tmpfiles re-applies the readable mode after
    # every boot, activating the built-in rapl collector
    # (node_rapl_package_joules_total). The glob covers every powercap zone
    # (package/core/dram/uncore on Intel, package-0/core on AMD). Effective on
    # next boot, or immediately via `systemd-tmpfiles --create`.
    systemd.tmpfiles.rules = [
      "z /sys/class/powercap/*/energy_uj 0444 - - -"
    ];

    # Postgres is only deployed as Nextcloud's database backend; scrape the
    # exporter (and alert on it) only when that stack exists.
    services.prometheus.exporters.postgres = mkIf config.modules.system.homelab.nextcloud.enable {
      enable = true;
      runAsLocalSuperUser = true;
    };

    services.grafana = {
      enable = true;
      settings = {
        server =
          {
            http_addr = "0.0.0.0";
            http_port = cfg.grafanaPort;
            domain = "m920q";
          }
          # Sub-path serving mirrors the Caddy route: Grafana mounts its app at
          # /grafana and the tailnet URL is canonical for redirects and assets.
          # Without the proxy route Grafana keeps serving from the root path.
          // lib.optionalAttrs (config.modules.system.homelab.caddyProxy.enable && config.modules.system.homelab.caddyProxy.grafana) {
            root_url = "https://${config.modules.system.homelab.caddyProxy.tailnetDomain}/grafana";
            serve_from_sub_path = true;
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
            {
              # Deploy-time closure metrics (emit-deploy-metrics.sh) and the
              # vitals health score. Always provisioned: the panels stay empty
              # until the first deploy or on hosts without the vitals daemon.
              name = "config-health";
              type = "file";
              disableDeletion = true;
              options.path = ./config-health-dashboard.json;
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
      };
    };

    # Alerting: Prometheus evaluates the rules, Alertmanager groups, dedups and
    # re-notifies them, and alertmanager-ntfy delivers each alert to the local
    # ntfy topic. Grafana keeps its dashboards and datasources only; its
    # unified alerting (query/reduce/threshold pipeline and provisioned
    # webhook payload) is gone.
    modules.system.homelab.monitoring.alerting.ruleGroups =
      mkIf cfg.alerting.enable homelabGroups;

    services.prometheus.globalConfig.evaluation_interval = "1m";

    # nixpkgs' lib.generators.toYAML is an alias of toJSON, so the rule file
    # is JSON. Prometheus (yaml.v3) accepts JSON, and services.prometheus.rules
    # is promtool-checked at build time, so a malformed rule fails the build.
    services.prometheus.rules = mkIf cfg.alerting.enable [
      (lib.generators.toYAML {} {
        groups = homelabGroups;
      })
    ];

    services.prometheus.alertmanagers = mkIf cfg.alerting.enable [
      {
        static_configs = [
          {
            targets = ["127.0.0.1:9093"];
          }
        ];
      }
    ];

    services.prometheus.alertmanager = mkIf cfg.alerting.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      configuration = {
        route = {
          receiver = "ntfy";
          # One notification per alert, grouped by rule and host. group_wait
          # coalesces a burst; repeat_interval bounds how often a still-firing
          # alert re-notifies.
          group_by = ["alertname" "host"];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
        };
        receivers = [
          {
            name = "ntfy";
            webhook_configs = [
              {
                url = "http://127.0.0.1:8000/hook";
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    # alertmanager-ntfy sends one ntfy message per alert. Priority comes
    # verbatim from the alert's `priority` label (ntfy names, set by the rule
    # groups); the title names the source host; tapping opens the Prometheus
    # expression that fired.
    services.prometheus.alertmanager-ntfy = mkIf cfg.alerting.enable {
      enable = true;
      settings = {
        http.addr = "127.0.0.1:8000";
        ntfy = {
          baseurl = "http://127.0.0.1:2586";
          notification = {
            topic = "homelab-alerts";
            priority = ''status == "resolved" ? "default" : alert.labels.priority'';
            tags = [
              {
                tag = "rotating_light";
                condition = ''status == "firing"'';
              }
              {
                tag = "white_check_mark";
                condition = ''status == "resolved"'';
              }
            ];
            templates = {
              title = ''{{ if eq .Status "resolved" }}Resolved: {{ end }}{{ index .Labels "alertname" }} on {{ index .Labels "host" }}'';
              description = ''{{ index .Annotations "description" }}'';
              headers = {
                "X-Click" = "{{ .GeneratorURL }}";
                "X-Markdown" = "yes";
              };
            };
          };
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
      after = ["prometheus.service"];
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

    # The Prometheus UI is root-absolute (/api/v1, / -> /query redirect), so
    # a path-stripping route cannot front it; like zellij-web, opencode-web
    # and homepage it gets its own Tailscale Serve port that terminates TLS
    # with the node certificate and needs no firewall change. The gate
    # mirrors the other serve units: without caddyProxy.tailnetDomain there
    # is no tailnet name to serve on.
    systemd.services.tailscale-serve-prometheus = mkIf hl.caddyProxy.enable {
      description = "Expose Prometheus UI via Tailscale Serve";
      after = [
        "tailscale.service"
        "prometheus.service"
      ];
      wants = [
        "tailscale.service"
        "prometheus.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStart = "${pkgs.writeShellScript "tailscale-serve-prometheus-setup" ''
          ${pkgs.tailscale}/bin/tailscale serve --bg \
            --https ${toString cfg.prometheusHttpsPort} \
            http://127.0.0.1:${toString cfg.prometheusPort}
        ''}";
      };
      # Fail loudly and retry when tailscaled is not yet connected; never
      # swallow the error into a green "active (exited)" state. Re-serve
      # whenever tailscaled comes back up.
      upholds = ["tailscale.service"];
      unitConfig.StartLimitBurst = 5;
      unitConfig.StartLimitIntervalSec = 300;
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
