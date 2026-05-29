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
          "hwmon"
          "thermal_zone"
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
            static_configs = [
              {
                targets = ["127.0.0.1:${toString cfg.nodeExporterPort}"];
              }
            ];
          }
          {
            job_name = "postgres";
            static_configs = [
              {
                targets = ["127.0.0.1:9187"];
              }
            ];
          }
        ]
        ++ lib.optionals config.modules.system.homelab.nextcloud.enable [
          {
            job_name = "nextcloud-exporter";
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
            static_configs = [
              {
                targets = ["127.0.0.1:${toString config.modules.system.homelab.adguardhome.port}"];
              }
            ];
            metrics_path = "/metrics";
          }
        ]
        ++ lib.optionals hasAppTargets [
          {
            job_name = "blackbox";
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
      };
    };

    sops.secrets = {
      "grafana/admin-password".owner = "grafana";
      "grafana/secret-key".owner = "grafana";
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
      serviceConfig = {
        EnvironmentFile = config.sops.templates."grafana-env".path;
        RestartSec = "5s";
        StartLimitBurst = 10;
        StartLimitIntervalSec = 60;
        ExecStartPre = [
          "+${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.prometheusPort}/-/healthy > /dev/null 2>&1; do sleep 2; done'"
        ];
      };
    };

    systemd.services.homelab-alerter = mkIf cfg.alerting.enable (
      let
        prometheusUrl = "http://127.0.0.1:${toString cfg.prometheusPort}";
        ntfyUrl = "http://127.0.0.1:2586/homelab-alerts";
        stateDir = "/var/lib/homelab-alerter";

        # Conditional alert definitions based on enabled services
        alertDefinitions =
          lib.optionals config.modules.system.homelab.nextcloud.enable [
            {
              name = "NextcloudDown";
              query = ''probe_success{job="blackbox",instance=~".*nextcloud.*"} == 0'';
              priority = "urgent";
              message = "Nextcloud is not responding to HTTP health probes";
            }
          ]
          ++ lib.optionals config.modules.system.homelab.immich.enable [
            {
              name = "ImmichDown";
              query = ''probe_success{job="blackbox",instance=~".*immich.*"} == 0'';
              priority = "urgent";
              message = "Immich is not responding to HTTP health probes";
            }
          ]
          ++ lib.optionals config.modules.system.homelab.adguardhome.enable [
            {
              name = "AdGuardDown";
              query = ''up{job="adguard"} == 0'';
              priority = "urgent";
              message = "AdGuard Home DNS server is not responding";
            }
          ]
          ++ [
            {
              name = "HighDiskUsage";
              query = ''node_filesystem_avail_bytes{mountpoint="/",fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/",fstype!="tmpfs"} < 0.1'';
              priority = "high";
              message = "Root filesystem is more than 90% full";
            }
            {
              name = "HighNixStoreUsage";
              query = ''node_filesystem_avail_bytes{mountpoint="/nix",fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/nix",fstype!="tmpfs"} < 0.15'';
              priority = "high";
              message = "Nix store is more than 85% full";
            }
            {
              name = "HighMemoryUsage";
              query = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9";
              priority = "high";
              message = "System memory usage is above 90%";
            }
            {
              name = "FailedSystemdUnits";
              query = ''count(node_systemd_unit_state{state="failed"}) > 0'';
              priority = "default";
              message = "There are failed systemd units";
            }
            {
              name = "NodeExporterDown";
              query = ''up{job="node"} == 0'';
              priority = "urgent";
              message = "Node exporter is unreachable (system metrics unavailable)";
            }
            {
              name = "PostgresDown";
              query = ''up{job="postgres"} == 0'';
              priority = "high";
              message = "PostgreSQL exporter is unreachable";
            }
          ];
        cooldownSeconds = 3600;
      in {
        description = "Homelab Prometheus alert bridge to ntfy";
        after = [
          "network.target"
          "prometheus.service"
          "ntfy-sh.service"
        ];
        wants = [
          "prometheus.service"
          "ntfy-sh.service"
        ];
        wantedBy = ["multi-user.target"];

        path = with pkgs; [curl];

        script = ''
          NTFY_URL="${ntfyUrl}"
          PROM_URL="${prometheusUrl}"
          STATE_DIR="${stateDir}"
          COOLDOWN=${toString cooldownSeconds}

          mkdir -p "$STATE_DIR"
          now=$(date +%s)
          cooldown_after=$((now - COOLDOWN))

          ntfy_send() {
            local title="$1" priority="$2" tags="$3" message="$4"
            ${pkgs.curl}/bin/curl -s -o /dev/null \
              -H "Title: $title" \
              -H "Priority: $priority" \
              -H "Tags: $tags" \
              -d "$message" \
              "$NTFY_URL" 2>/dev/null || true
          }

          check_alert() {
            local name="$1" query="$2" priority="$3" message="$4"
            local state_file="$STATE_DIR/$name"

            result=$(${pkgs.curl}/bin/curl -G -s "$PROM_URL/api/v1/query" \
              --data-urlencode "query=$query" 2>/dev/null || echo '{"status":"error"}')

            if echo "$result" | ${pkgs.gnugrep}/bin/grep -q '"result":\[\]' 2>/dev/null; then
              firing=false
            else
              firing=true
            fi

            if $firing; then
              local last_fired=0
              [[ -f "$state_file" ]] && last_fired=$(cat "$state_file" 2>/dev/null || echo 0)
              if [[ $last_fired -lt $cooldown_after ]]; then
                ntfy_send "$name" "$priority" "warning" "$message"
              fi
              echo "$now" > "$state_file"
            else
              if [[ -f "$state_file" ]]; then
                ntfy_send "$name resolved" "low" "white_check_mark" "$message"
                rm -f "$state_file"
              fi
            fi
          }

          ${lib.concatMapStringsSep "\n" (alert: ''
              check_alert "${alert.name}" "${alert.query}" "${alert.priority}" "${alert.message}"
            '')
            alertDefinitions}
        '';

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          StateDirectory = "homelab-alerter";
        };
      }
    );

    systemd.timers.homelab-alerter = mkIf cfg.alerting.enable {
      description = "Timer for homelab alert checker";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*:0/2";
        Persistent = true;
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
