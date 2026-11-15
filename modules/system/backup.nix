{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.backup;
  inherit (lib) types;

  # Pool backing a syncoid endpoint dataset (first path component).
  poolOf = dataset: lib.head (lib.splitString "/" dataset);
in {
  options.modules.system.homelab.backup = {
    enable = lib.mkEnableOption "Backup configuration (sanoid snapshots + syncoid replication)";

    sanoidDatasets = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          hourly = lib.mkOption {
            type = types.int;
            default = 24;
          };
          daily = lib.mkOption {
            type = types.int;
            default = 7;
          };
          weekly = lib.mkOption {
            type = types.int;
            default = 4;
          };
          monthly = lib.mkOption {
            type = types.int;
            default = 12;
          };
          yearly = lib.mkOption {
            type = types.int;
            default = 1;
          };
          recursive = lib.mkOption {
            type = types.bool;
            default = false;
          };
          # 15-min snapshot layer (sanoid's frequent/frequent_period from
          # sanoid.defaults.conf). Carries the zfs-auto-snapshot frequent
          # coverage after zfstools opts out of a dataset via
          # com.sun:auto-snapshot=false, which this module implies by
          # declaring the dataset here.
          frequently = lib.mkOption {
            type = types.int;
            default = 0;
            description = "Number of 15-min snapshots to keep (0 disables).";
          };
          frequentPeriod = lib.mkOption {
            type = types.int;
            default = 15;
            description = "Minutes between frequent snapshots.";
          };
        };
      });
      default = {
        "rpool/eyd/per" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 1;
          recursive = true;
        };
      };
      description = "Datasets for sanoid snapshot management";
    };

    syncoidInterval = lib.mkOption {
      type = types.str;
      default = "20:00";
      description = "Syncoid replication schedule (systemd calendar format)";
    };

    syncoidCommands = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          source = lib.mkOption {
            type = types.str;
            description = "Source ZFS dataset";
          };
          target = lib.mkOption {
            type = types.str;
            description = "Target ZFS dataset";
          };
          sendOptions = lib.mkOption {
            type = types.str;
            default = "w";
            description = "ZFS send options (e.g. w for raw, L for large blocks)";
          };
          recvOptions = lib.mkOption {
            type = types.str;
            default = "";
            description = "ZFS receive options (u skips mounting the received dataset)";
          };
          recursive = lib.mkOption {
            type = types.bool;
            default = false;
            description = "Replicate child datasets too (syncoid --recursive)";
          };
          extraArgs = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra syncoid arguments for this command";
          };
        };
      });
      default = {};
      description = "Syncoid replication commands";
    };

    status = {
      enable = lib.mkEnableOption "per-route backup success metrics for the dashboard and staleness rules";

      textfileDirectory = lib.mkOption {
        type = types.str;
        default = "/var/lib/node-exporter/textfile";
        description = "node_exporter textfile collector directory";
      };

      routes = lib.mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            unit = lib.mkOption {
              type = types.str;
              description = "Systemd service (short name) whose successful exit stamps the route";
            };
            maxAge = lib.mkOption {
              type = types.str;
              description = "Longest acceptable time since the last successful run (30m, 26h, 14d)";
            };
            firstRunGrace = lib.mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Time allowed for the first successful run before BackupNeverSucceeded pages (default: maxAge)";
            };
            description = lib.mkOption {
              type = types.str;
              default = "";
              description = "Human-readable route name for alerts and the dashboard";
            };
          };
        });
        default = {};
        description = "Backup routes whose last successful run is exported and alerted on";
      };
    };
  };

  config = lib.mkIf cfg.enable (let
    # sanoid addresses datasets by name, so a dataset on a lazily imported
    # pool (the USB backup pool) is invisible until something triggers the
    # import. Pull the import units in like the syncoid services do; Wants
    # keeps hosts whose pools have no generated import unit working.
    sanoidImportUnits = map (pool: "zfs-import-${pool}.service") (
      lib.unique (map poolOf (lib.attrNames cfg.sanoidDatasets))
    );

    # Per-route success metrics. systemd's ExecStartPost only runs when the
    # main command exited 0, so a stamp is proof of a successful run, not of
    # an attempt; a failed run leaves the previous stamp in place and the
    # staleness rule then measures the real age. The static route table (max
    # age, first seen) is what lets "never succeeded" be distinguished from
    # "succeeded once, then stopped".
    promLabel = s: builtins.replaceStrings ["\\" "\"" "\n"] ["\\\\" "\\\"" " "] s;

    toSeconds = v: let
      m = builtins.match "([0-9]+)([smhdw])" v;
      mult = {
        s = 1;
        m = 60;
        h = 3600;
        d = 86400;
        w = 604800;
      };
    in
      if m == null
      then throw "modules.system.homelab.backup.status.routes.*.maxAge must look like 30m, 26h, 14d or 4w (got '${v}')"
      else lib.toInt (builtins.elemAt m 0) * mult.${builtins.elemAt m 1};

    stampScript = name: route:
      pkgs.writeShellScript "backup-stamp-${name}" ''
        set -eu
        dir=${lib.escapeShellArg cfg.status.textfileDirectory}
        [ -d "$dir" ] || exit 0
        tmp="$dir/.backup-${name}.$$"
        printf 'backup_last_success_timestamp_seconds{route="%s",description="%s"} %s\n' \
          ${lib.escapeShellArg name} ${lib.escapeShellArg (promLabel route.description)} \
          "$(${pkgs.coreutils}/bin/date +%s)" >"$tmp"
        # The unit's UMask applies to the stamp (the syncoid units use 0077);
        # the collector runs as node-exporter and must be able to read it.
        ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$dir/backup-${name}.prom"
      '';

    statusRoutes = lib.filterAttrs (_: _: cfg.status.enable) cfg.status.routes;
  in
    lib.mkMerge [
      {
        services.sanoid = {
          enable = true;
          # Map the module's frequency keys onto sanoid's own dataset config:
          # frequently -> frequently, frequentPeriod -> frequent_period
          # (verified keys in sanoid 2.3.0 sanoid.defaults.conf). recursive
          # is a nixpkgs sanoid module option, not a sanoid config key.
          datasets =
            lib.mapAttrs (
              _: ds: (lib.filterAttrs (_: v: v != null) {
                inherit (ds) hourly daily weekly monthly yearly recursive;
                frequently =
                  if ds.frequently == 0
                  then null
                  else ds.frequently;
                frequent_period =
                  if ds.frequently == 0
                  then null
                  else ds.frequentPeriod;
              })
            )
            cfg.sanoidDatasets;
        };

        services.syncoid = {
          enable = true;
          interval = cfg.syncoidInterval;
          group = "root";
          commands = cfg.syncoidCommands;
          # Upstream default target permissions lack destroy/hold, so syncoid
          # cannot prune old syncoid_* snapshots on the replica: it logs
          # "cannot destroy snapshots: permission denied" every run and the
          # backup dataset accretes stale nightlies (observed: 1331 snapshots,
          # ~96 GiB pinned on bpool/backup/data). destroy + hold add the
          # prune privileges the noop-retain option expects; the remaining
          # entries mirror the upstream default.
          localTargetAllow = [
            "change-key"
            "compression"
            "create"
            "destroy"
            "hold"
            "mount"
            "mountpoint"
            "receive"
            "rollback"
          ];
        };

        systemd.services =
          lib.mapAttrs' (
            name: cmd: let
              pools = lib.unique [(poolOf cmd.source) (poolOf cmd.target)];
              importUnits = map (pool: "zfs-import-${pool}.service") pools;
            in
              lib.nameValuePair "syncoid-${name}" {
                # Pools whose filesystems are all `noauto` import only on first
                # mount access, so after a reboot they stay exported until
                # something touches the mountpoint — which syncoid never does
                # (it addresses datasets by name). Pulling the import units makes
                # each run self-sufficient: no-op when already imported, retried
                # while USB devices enumerate. Wants (not Requires): consumers
                # without import units (e.g. the VM test, which creates pools
                # ad-hoc) must still start, and a failed import is caught below
                # by the fail-fast guard with a clearer message. Pulled in only
                # by the backup timer, never by boot.
                after = importUnits;
                wants = importUnits;
                preStart = ''
                  set -eu
                  # Fail fast when the target pool is absent (e.g. USB backup drive
                  # not imported): the ancestor walk below strips path components,
                  # but a bare pool name contains no slash so %/* is a no-op and an
                  # unguarded loop spins until systemd kills preStart on timeout.
                  target_parent="${cmd.target}"
                  while [ -n "$target_parent" ] && ! ${pkgs.zfs}/bin/zfs list "$target_parent" >/dev/null 2>&1; do
                    stripped="''${target_parent%/*}"
                    if [ "$stripped" = "$target_parent" ]; then
                      echo "ERROR: target ${cmd.target} does not exist (pool not imported?). Aborting backup."
                      exit 1
                    fi
                    target_parent="$stripped"
                  done
                  if [ -z "$target_parent" ]; then
                    echo "ERROR: target ${cmd.target} does not exist (pool not imported?). Aborting backup."
                    exit 1
                  fi
                  avail=$(${pkgs.zfs}/bin/zfs get -Hpo value available "$target_parent" 2>/dev/null || echo "0")
                  if [ "$avail" -lt 1073741824 ]; then
                    echo "ERROR: $target_parent has only $avail bytes available (< 1GB). Aborting backup."
                    exit 1
                  fi
                '';
                # Abort a broken partial receive before the sync starts. The abort
                # needs the receive delegation, which the syncoid module grants in
                # its own ExecStartPre entries and revokes in ExecStopPost, so this
                # runs after them: mkAfter appends behind its `-+` allow commands,
                # and the `+` here carries the privilege the delegation check
                # requires. A failing abort is non-fatal; the sync that follows
                # reports the real problem.
                serviceConfig.ExecStartPre = lib.mkAfter [
                  "-+${pkgs.zfs}/bin/zfs receive -A ${cmd.target}"
                ];
                serviceConfig.WorkingDirectory = "-/";
              }
          )
          cfg.syncoidCommands
          // {
            sanoid = {
              after = sanoidImportUnits;
              wants = sanoidImportUnits;
            };
          };

        # The static half of the route metrics: the expected routes, their max
        # age and when each was first configured. A fresh route gets a 24h grace
        assertions =
          lib.mapAttrsToList (name: route: {
            assertion = builtins.hasAttr route.unit config.systemd.services;
            message = "modules.system.homelab.backup.status.routes.${name} references systemd service '${route.unit}', which is not defined";
          })
          statusRoutes;
      }
      # Stamps live in their own module definition so the module system merges
      # them into units defined here (the syncoid services) and elsewhere
      # (postgresqlBackup, zigbee) instead of `//` replacing the whole unit.
      {
        systemd.services =
          lib.mapAttrs' (name: route:
            lib.nameValuePair route.unit {
              # `+` bypasses the unit's User= and sandbox so the stamp can write
              # into the root-owned textfile directory even for backup units that
              # run as postgres or zigbee2mqtt.
              serviceConfig.ExecStartPost = lib.mkAfter ["+${stampScript name route}"];
            })
          statusRoutes
          // {
            # The static half of the route metrics: the expected routes, their
            # max age and when each was first configured. A fresh route gets a
            # 24h grace before "never succeeded" pages, and the state file is
            # what keeps that grace from restarting on every deploy or reboot.
            backup-route-metrics = lib.mkIf (statusRoutes != {}) {
              description = "Publish the expected backup routes and their maximum ages";
              wantedBy = ["multi-user.target"];
              path = [pkgs.coreutils];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                set -eu
                dir=${lib.escapeShellArg cfg.status.textfileDirectory}
                [ -d "$dir" ] || exit 0
                state=/var/lib/backup-status
                mkdir -p "$state"
                tmp="$dir/.backup-routes.$$"
                : >"$tmp"
                ${lib.concatStrings (lib.mapAttrsToList (name: route: ''
                    first="$state/${name}.first-seen"
                    [ -s "$first" ] || date +%s >"$first"
                    printf 'backup_route_expected{route="%s",description="%s"} 1\n' \
                      ${lib.escapeShellArg name} ${lib.escapeShellArg (promLabel route.description)} >>"$tmp"
                    printf 'backup_max_age_seconds{route="%s",description="%s"} %s\n' \
                      ${lib.escapeShellArg name} ${lib.escapeShellArg (promLabel route.description)} ${toString (toSeconds route.maxAge)} >>"$tmp"
                    # First-run grace: never alarm a fresh route before its
                    # first expected window, and never sooner than a day (the
                    # hourly routes would otherwise page within three hours).
                    printf 'backup_first_run_grace_seconds{route="%s",description="%s"} %s\n' \
                      ${lib.escapeShellArg name} ${lib.escapeShellArg (promLabel route.description)} ${toString (lib.max 86400 (toSeconds (
                      if route.firstRunGrace == null
                      then route.maxAge
                      else route.firstRunGrace
                    )))} >>"$tmp"
                    printf 'backup_route_first_seen_timestamp_seconds{route="%s",description="%s"} %s\n' \
                      ${lib.escapeShellArg name} ${lib.escapeShellArg (promLabel route.description)} "$(cat "$first")" >>"$tmp"
                  '')
                  cfg.status.routes)}
                mv "$tmp" "$dir/backup-routes.prom"

                # Drop stamps for routes that no longer exist, so a renamed
                # route does not keep publishing a last-success forever.
                keep=" ${lib.concatStringsSep " " (map (n: "backup-${n}.prom") (builtins.attrNames cfg.status.routes))} "
                for f in "$dir"/backup-*.prom; do
                  [ -e "$f" ] || continue
                  base=''${f##*/}
                  [ "$base" = backup-routes.prom ] && continue
                  case "$keep" in
                    *" $base "*) ;;
                    *) rm -f "$f" ;;
                  esac
                done
              '';
            };
          };
      }
    ]);
}
