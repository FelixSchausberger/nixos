# Log aggregation: Loki stores the fleet's journald logs and Grafana queries
# them next to the metrics, so a failed deploy, a probe failure or a vitals
# finding can be followed to the lines that caused it. The aggregator host runs
# Loki; every host (the aggregator included) ships its journal through Grafana
# Alloy, so one Grafana spans the whole fleet instead of one journald per host.
#
# Alloy reads the journal directly rather than going through the OpenTelemetry
# collector: journald is the source and Loki the sink, neither speaks OTLP, and
# the collector's metrics pipeline is separate from this. Spans already handled
# there stay on loopback; log lines do not carry store paths the way spans do,
# but they are treated with the same default of not leaving the LAN/tailnet.
{
  inputs,
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.logging;
  inherit (lib) mkIf;

  dataDir = "/var/lib/loki";

  # Grafana Alloy pipeline. The host label is the only per-machine input: it
  # becomes the `host` stream label, so {host="desktop"} scopes a query to one
  # machine. `unit` and `level` are lifted from journal fields so the error view
  # can filter by service and severity without pattern-matching the message.
  #
  # Two journald properties need correcting before the labels are usable:
  #
  #   - A process that writes to stderr without a syslog prefix reaches the
  #     journal as PRIORITY=6, so a Postgres ERROR or a Go/Rust `level=error`
  #     line is stored as info. The process stages below read the severity the
  #     application itself printed and override the journald guess; lines that
  #     match neither shape keep their journald level.
  #   - The priority keyword is "err", not "error" (and "warning" rather than
  #     "warn"), so a dashboard filtering level="error" saw nothing even for
  #     real journald errors. The relabel rules normalise it first.
  #
  # User units carry their own service name in __journal__systemd_user_unit;
  # without that label every kiosk or status-bar line collapses into
  # user@1000.service and per-service views cannot name the failing unit.
  alloyConfig = endpoint: host: syslog: ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }

      rule {
        source_labels = ["level"]
        regex         = "err|crit|alert|emerg"
        target_label  = "level"
        replacement   = "error"
      }

      rule {
        source_labels = ["level"]
        regex         = "warning"
        target_label  = "level"
        replacement   = "warn"
      }

      rule {
        source_labels = ["level"]
        regex         = "notice"
        target_label  = "level"
        replacement   = "info"
      }

      // The capture group is load-bearing: relabel's default replacement is
      // `$1`, so a bare `.+` matches but expands to an empty label value.
      // Systems units have no user unit and do not match at all.
      rule {
        source_labels = ["__journal__systemd_user_unit"]
        regex         = "(.+)"
        target_label  = "user_unit"
      }
    }

    loki.process "levels" {
      forward_to = [loki.write.loki.receiver]

      // logfmt shape: `level=error`, `level="warning"`, `level=DEBUG`.
      stage.regex {
        expression = "(?i)(?:^|\\s)level=(?P<app_level>error|warn(?:ing)?|info|debug|trace|fatal|crit(?:ical)?|alert|emerg|notice)\\b"
      }

      // `with .Value` keeps a non-matching line from acquiring an empty
      // app_level, which the labels stage would otherwise write as level="".
      stage.template {
        source   = "app_level"
        template = "{{ with .Value }}{{ if eq (. | ToLower) \"warning\" }}warn{{ else if or (eq (. | ToLower) \"fatal\") (eq (. | ToLower) \"critical\") (eq (. | ToLower) \"crit\") (eq (. | ToLower) \"alert\") (eq (. | ToLower) \"emerg\") }}error{{ else if eq (. | ToLower) \"notice\" }}info{{ else }}{{ . | ToLower }}{{ end }}{{ end }}"
      }

      stage.labels {
        values = { level = "app_level" }
      }

      // Postgres writes `[pid] ERROR: ...` to stderr without a level prefix;
      // this is the shape behind the oc_mounts duplicate-key flood.
      stage.regex {
        expression = "^\\[[0-9]+\\] (?P<pg_level>ERROR|FATAL|PANIC|WARNING|NOTICE|INFO|LOG|DEBUG[1-5]?|STATEMENT|DETAIL|HINT):"
      }

      stage.template {
        source   = "pg_level"
        template = "{{ with .Value }}{{ if eq . \"WARNING\" }}warn{{ else if or (eq . \"ERROR\") (eq . \"FATAL\") (eq . \"PANIC\") }}error{{ else }}info{{ end }}{{ end }}"
      }

      stage.labels {
        values = { level = "pg_level" }
      }
    }

    loki.source.journal "journal" {
      forward_to    = [loki.process.levels.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = {host = "${host}"}
      max_age       = "24h"
    }

    ${syslog}

    loki.write "loki" {
      endpoint {
        url = "${endpoint}/loki/api/v1/push"
      }
    }
  '';

  # The aggregator ships its own journal to the loopback listener; a client
  # host ships wherever it was pointed.
  alloyEndpoint =
    if cfg.shipEndpoint != null
    then cfg.shipEndpoint
    else "http://127.0.0.1:${toString cfg.lokiPort}";
  alloyEnabled = cfg.enable || cfg.shipEndpoint != null;

  # Syslog receiver for the SLZB coordinator on the aggregator only. The
  # device buffers its boot log and flushes it when the sender starts, so the
  # component exists to keep those lines searchable next to the journald logs.
  # Client hosts keep it out of their config; the listener is UDP and
  # unauthenticated, so the firewall rule below scopes it to the coordinator.
  syslogComponent = lib.optionalString (cfg.enable && cfg.syslogSource != null) ''
    loki.source.syslog "slzb" {
      listener {
        address       = "0.0.0.0:${toString cfg.syslogPort}"
        protocol      = "udp"
        syslog_format = "rfc3164"
        labels        = {job = "syslog", device = "slzb-mr4u"}
      }

      forward_to = [loki.write.loki.receiver]
    }
  '';
in {
  options.modules.system.homelab.logging = {
    enable = lib.mkEnableOption "Loki log aggregation (store, query, Grafana datasource)";
    lokiPort = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.loki;
      description = "Loki HTTP port (loopback, tailnet, and the clientSources list)";
    };
    clientSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        LAN addresses (IP or CIDR) allowed to push logs to Loki. The tailnet
        interface is trusted already; an empty list leaves Loki reachable only
        over loopback and the tailnet.
      '';
    };
    shipEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Loki base URL this host ships its journald to through Alloy. Leave it
        null on the aggregator host, which ships to the local listener; set it
        on client hosts.
      '';
    };
    syslogSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        LAN address allowed to send RFC3164 syslog to the Alloy listener. Set
        it to the Zigbee coordinator's reserved address; null keeps the UDP
        listener and its firewall rule out of the configuration.
      '';
    };
    syslogPort = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.syslog;
      description = "UDP port of the Alloy syslog listener";
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      services.loki = {
        enable = true;
        inherit dataDir;
        # Single-binary filesystem deployment: chunks and the tsdb index live
        # under dataDir, no object store or external services. 30d retention is
        # enforced by the compactor; without retention_enabled + a delete
        # request store, Loki would grow without bound on the pool.
        configuration = {
          auth_enabled = false;
          analytics.reporting_enabled = false;
          server = {
            http_listen_address = "0.0.0.0";
            http_listen_port = cfg.lokiPort;
            grpc_listen_port = 9095;
            # Loki logs every query it answers at info, and Alloy ships its
            # journal back into Loki: the query text becomes a log line whose
            # own searches then match, inflating storage and returning the
            # search itself as a hit. Warnings and errors still ship.
            log_level = "warn";
          };
          common = {
            instance_addr = "127.0.0.1";
            path_prefix = dataDir;
            storage.filesystem = {
              chunks_directory = "${dataDir}/chunks";
              rules_directory = "${dataDir}/rules";
            };
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };
          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
          limits_config.retention_period = "30d";
          compactor = {
            working_directory = "${dataDir}/compactor";
            retention_enabled = true;
            delete_request_store = "filesystem";
          };
        };
      };

      # Loki is unauthenticated and stores every journal line, so it is not
      # opened LAN-wide the way Grafana is: only the hosts named in
      # clientSources may reach the push API. The tailnet interface is trusted,
      # so a tailnet client needs no rule here. One accept rule per source keeps
      # the generated nftables free of set-literal syntax.
      networking.firewall.extraInputRules = lib.mkIf (cfg.clientSources != [] || cfg.syslogSource != null) (
        lib.concatStringsSep "\n" (
          map
          (source: "ip saddr ${source} tcp dport ${toString cfg.lokiPort} accept")
          cfg.clientSources
          ++ lib.optional (cfg.syslogSource != null)
          "ip saddr ${cfg.syslogSource} udp dport ${toString cfg.syslogPort} accept"
        )
      );

      environment.persistence."/per".directories = [
        {
          directory = dataDir;
          user = "loki";
          group = "loki";
          mode = "0700";
        }
      ];
    })
    (mkIf alloyEnabled {
      services.alloy.enable = true;
      # Alloy posts an anonymous usage report to stats.grafana.org every two
      # hours. This host's AdGuard resolves that domain to 0.0.0.0, so each
      # attempt fails the TLS handshake and logs a warn line; reporting is
      # optional telemetry, so it is switched off rather than left warning.
      services.alloy.extraFlags = ["--disable-reporting"];
      # The upstream module runs Alloy as a DynamicUser, whose state directory is
      # /var/lib/private/alloy under a /var/lib/private that systemd requires to
      # be mode 0700. Persisting a path inside it fights that setup: the parent
      # comes back 0755 from the persistence tree and systemd aborts the unit
      # with STATE_DIRECTORY, restarting into start-limit-hit. A static user
      # moves the state to /var/lib/alloy, which persists cleanly - the same fix
      # homepage.nix applies to its dashboard. The journal groups go on the user
      # so the process keeps read access to the systemd journal.
      users.users.alloy = {
        isSystemUser = true;
        group = "alloy";
        extraGroups = ["systemd-journal" "adm"];
      };
      users.groups.alloy = {};
      systemd.services.alloy.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = lib.mkForce "alloy";
        Group = lib.mkForce "alloy";
      };
      # systemd stops units in reverse start order, so ordering Alloy after
      # Loki makes Alloy stop first and flush its queue while the sink is still
      # accepting; without it a switch stops Loki first and Alloy drops the
      # final batch with "connect: connection refused".
      systemd.services.alloy.after = lib.optional cfg.enable "loki.service";
      environment.etc."alloy/config.alloy".text =
        alloyConfig alloyEndpoint config.networking.hostName syslogComponent;
      # Alloy keeps its journal read position under its state directory. That
      # lives on tmpfs, so an unpersisted cursor is lost every boot and the last
      # max_age window is shipped again; persisting it lets a restart resume
      # where it stopped instead of duplicating logs in Loki.
      environment.persistence."/per".directories = [
        {
          directory = "/var/lib/alloy";
          user = "alloy";
          group = "alloy";
          mode = "0700";
        }
      ];
    })
  ];
}
