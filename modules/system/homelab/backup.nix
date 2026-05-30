{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.homelab.backup = {
    enable = lib.mkEnableOption "Backup configuration (sanoid snapshots + syncoid replication)";
  };

  config = lib.mkIf config.modules.system.homelab.backup.enable {
    services.sanoid = {
      enable = true;
      datasets = {
        "dpool/data" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 1;
        };
        "rpool/eyd/per" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 1;
          recursive = true;
        };
      };
    };

    services.syncoid = {
      enable = true;
      interval = "20:00";
      group = "root";
      commands = {
        "dpool-data-to-bpool-backup" = {
          source = "dpool/data";
          target = "bpool/backup/data";
          sendOptions = "w";
        };
      };
    };

    systemd.services.syncoid-dpool-data-to-bpool-backup = {
      preStart = ''
        # Abort any broken partial receive before starting sync
        ${pkgs.zfs}/bin/zfs receive -A bpool/backup/data 2>/dev/null || true
      '';
      serviceConfig.WorkingDirectory = "-/";
    };
  };
}
