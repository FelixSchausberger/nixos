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
        };
      });
      default = {};
      description = "Syncoid replication commands";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sanoid = {
      enable = true;
      datasets = cfg.sanoidDatasets;
    };

    services.syncoid = {
      enable = true;
      interval = cfg.syncoidInterval;
      group = "root";
      commands = cfg.syncoidCommands;
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
            # (it addresses datasets by name). Requiring the import units
            # makes each run self-sufficient: no-op when already imported,
            # retried while USB devices enumerate, immediate dependency
            # failure when the drive is absent. Pulled in only by the backup
            # timer, never by boot.
            after = importUnits;
            requires = importUnits;
            preStart = ''
              set -eu
              # Abort any broken partial receive before starting sync
              ${pkgs.zfs}/bin/zfs receive -A ${cmd.target} 2>/dev/null || true
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
            serviceConfig.WorkingDirectory = "-/";
          }
      )
      cfg.syncoidCommands;
  };
}
