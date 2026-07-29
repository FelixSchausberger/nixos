{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.backup;
  inherit (lib) types;
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
        name: cmd:
          lib.nameValuePair "syncoid-${name}" {
            preStart = ''
              set -eu
              # Abort any broken partial receive before starting sync
              ${pkgs.zfs}/bin/zfs receive -A ${cmd.target} 2>/dev/null || true
              # Check target pool has enough free space (abort early instead of crashing)
              avail=$(${pkgs.zfs}/bin/zfs get -Hpo value available ${cmd.target} 2>/dev/null || echo "0")
              if [ "$avail" -lt 1073741824 ]; then
                echo "ERROR: ${cmd.target} has only $avail bytes available (< 1GB). Aborting backup."
                exit 1
              fi
            '';
            serviceConfig.WorkingDirectory = "-/";
          }
      )
      cfg.syncoidCommands;
  };
}
