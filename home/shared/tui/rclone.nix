{
  config,
  pkgs,
  ...
}: let
  mountdir = "/per/mnt/gdrive";
in {
  programs.rclone = {
    enable = true;
    package = pkgs.rclone;

    remotes.gdrive = {
      config = {
        type = "drive";
        scope = "drive";
        root_folder_id = "0AGsk4MwDWp9HUk9PVA";
        config_is_local = true;
        config_refresh_token = false;
        server_side_across_configs = true;
        disable_http2 = true;

        token = config.sops.secrets."rclone/token".path;
      };

      secrets = {
        client_id = config.sops.secrets."rclone/client-id".path;
        client_secret = config.sops.secrets."rclone/client-secret".path;
        token = config.sops.secrets."rclone/token".path;
      };
    };
  };

  sops.secrets = {
    "rclone/client-id" = {};
    "rclone/client-secret" = {};
    "rclone/token" = {};
  };

  # Rest of your configuration remains the same
  systemd.user.services.gdrive-mount = {
    Unit = {
      Description = "Google Drive Mount";
      After = [
        "sops-nix.service"
      ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountdir}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount \
          --config=${config.xdg.configHome}/rclone/rclone.conf \
          --vfs-cache-mode full \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-size-limit 1G \
          --buffer-size 256M \
          --log-level INFO \
          --allow-other \
          gdrive: ${mountdir}
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount -uz ${mountdir}";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = ["default.target"];
    };
  };
}
