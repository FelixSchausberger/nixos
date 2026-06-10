{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.services.postgresql.enable {
    environment.persistence."/per".directories = [
      "/var/lib/postgresql"
    ];

    systemd.services.postgresql = {
      after = ["var-lib-postgresql.mount"];
      requires = ["var-lib-postgresql.mount"];
    };

    services.postgresql.settings = {
      wal_level = "replica";
      archive_mode = "on";
      archive_command = "${pkgs.coreutils}/bin/cp %p /var/lib/postgresql/wal_archive/%f";
      max_wal_size = "2GB";
      min_wal_size = "512MB";
      checkpoint_completion_target = 0.9;
    };

    systemd.tmpfiles.rules = [
      "d /per/var/lib/postgresql/wal_archive 0700 postgres postgres -"
    ];
  };
}
