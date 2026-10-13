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
  alloyConfig = endpoint: host: ''
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
    }

    loki.source.journal "journal" {
      forward_to    = [loki.write.loki.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = {host = "${host}"}
      max_age       = "24h"
    }

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
in {
  options.modules.system.homelab.logging = {
    enable = lib.mkEnableOption "Loki log aggregation (store, query, Grafana datasource)";
    lokiPort = lib.mkOption {
      type = lib.types.port;
      default = 3100;
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
      networking.firewall.extraInputRules = lib.mkIf (cfg.clientSources != []) (
        lib.concatMapStringsSep "\n"
        (source: "ip saddr ${source} tcp dport ${toString cfg.lokiPort} accept")
        cfg.clientSources
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
      environment.etc."alloy/config.alloy".text =
        alloyConfig alloyEndpoint config.networking.hostName;
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
