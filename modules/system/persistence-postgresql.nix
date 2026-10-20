{
  config,
  lib,
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

    # No WAL archiving: the fleet runs no streaming standby and nothing
    # replays archived segments (no PITR consumer either), while pg_wal
    # recycles its own segments without one. Any archive_command would
    # only pile dead files onto rpool (~1 GB/month measured on m920q by
    # 2026-10). Reintroduce archiving together with the consumer that
    # needs it, with a retention story attached.
    services.postgresql.settings = {
      max_wal_size = "2GB";
      min_wal_size = "512MB";
      checkpoint_completion_target = 0.9;
      shared_buffers = "2GB";
      effective_cache_size = "8GB";
      work_mem = "8MB";
      maintenance_work_mem = "256MB";
      max_connections = "50";
    };
  };
}
