# System-side option for the vitals health monitoring daemon.
# The daemon/CLI wiring lives in the home-manager module
# (modules/home/tui/vitals.nix), which reads services.vitals.headless from
# osConfig to pick the session target.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vitals;
  nodeExporter = config.services.prometheus.exporters.node;
in {
  options.services.vitals = {
    enable = lib.mkEnableOption "vitals health monitoring daemon";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run on a headless server (use default.target instead of graphical-session.target)";
    };

    textfile = {
      enable = lib.mkEnableOption ''
        publishing the health score through the node exporter textfile
        collector, for a host the central Prometheus does not scrape vitals on
      '';

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/node-exporter/textfile";
        description = "Directory the node exporter textfile collector reads.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "60s";
        description = "How often the health score is written.";
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.textfile.enable) {
    assertions = [
      {
        assertion = nodeExporter.enable;
        message = "services.vitals.textfile.enable needs the node exporter, whose textfile collector carries the score";
      }
    ];

    # The daemon binds loopback, so a host that runs no monitoring stack is
    # invisible to the central Prometheus. Writing the score into the node
    # exporter's textfile collector instead rides the node exporter scrape the
    # central Prometheus already has for this host.
    services.prometheus.exporters.node.extraFlags = [
      "--collector.textfile.directory=${cfg.textfile.directory}"
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.textfile.directory} 0755 ${nodeExporter.user} ${nodeExporter.group} -"
    ];

    systemd.services.vitals-metrics = {
      description = "Write the vitals health score for the node exporter textfile collector";
      serviceConfig = {
        Type = "oneshot";
        # The daemon owns journal access; this unit only copies its loopback
        # /metrics response, so it runs as the exporter user that owns the
        # collector directory instead of root.
        User = nodeExporter.user;
        Group = nodeExporter.group;
      };
      script = ''
        set -euo pipefail
        dir="${cfg.textfile.directory}"
        tmp="$(${pkgs.coreutils}/bin/mktemp "$dir/.vitals.XXXXXX")"
        trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
        # The daemon's /metrics response is the same series a Prometheus scrape
        # receives, so the textfile and scrape paths share one emitter. The
        # textfile collector does not support timestamps, so each sample's
        # trailing field is stripped.
        ${pkgs.curl}/bin/curl -sf --max-time 30 http://127.0.0.1:8080/metrics \
          | ${pkgs.gnused}/bin/sed -E 's/[[:space:]][0-9]+$//' > "$tmp"
        ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$dir/vitals.prom"
      '';
    };

    systemd.timers.vitals-metrics = {
      description = "Refresh the vitals health score textfile metric";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.textfile.interval;
        Unit = "vitals-metrics.service";
      };
    };
  };
}
