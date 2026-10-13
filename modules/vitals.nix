# System-side option for the vitals health monitoring daemon.
# The daemon/CLI wiring lives in the home-manager module
# (modules/home/tui/vitals.nix), which reads services.vitals.headless from
# osConfig to pick the session target.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vitals;
  daemon = inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.daemon;
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
        assertion = config.services.prometheus.exporters.node.enable;
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
      "d ${cfg.textfile.directory} 0755 node-exporter node-exporter -"
    ];

    systemd.services.vitals-metrics = {
      description = "Write the vitals health score for the node exporter textfile collector";
      serviceConfig = {
        Type = "oneshot";
        # Reads the whole system journal; same privilege as the maintenance check.
        User = "root";
      };
      script = ''
        set -euo pipefail
        dir="${cfg.textfile.directory}"
        tmp="$(${pkgs.coreutils}/bin/mktemp "$dir/.vitals.XXXXXX")"
        trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
        # Every sample the daemon prints carries a millisecond timestamp; the
        # textfile collector wants bare samples (as the deploy and GC emitters
        # write them), so the trailing timestamp field is dropped.
        ${daemon}/bin/vitals-daemon --once --format prometheus \
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
