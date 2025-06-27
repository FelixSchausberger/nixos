{config, ...}: let
  mountdir = "/per/mnt/gdrive";
  root_folder_id = "0AGsk4MwDWp9HUk9PVA";
  client_id = "1009718778774-dt220ti1a4qpoo1p0u91umdhonavfn6h.apps.googleusercontent.com";
in {
  programs.rclone = {
    enable = true;

    remotes = {
      gdrive = {
        config = {
          type = "drive";
          scope = "drive";
          root_folder_id = "0AGsk4MwDWp9HUk9PVA";
          client_id = "1009718778774-dt220ti1a4qpoo1p0u91umdhonavfn6h.apps.googleusercontent.com";
          config_is_local = true;
          disable_http2 = true;
        };

        secrets = {
          client_secret = config.sops.secrets."rclone/client-secret".path;
          token = config.sops.secrets."rclone/token".path;
        };

        mounts."" = {
          enable = true;
          mountPoint = mountdir;
          options = {
            allow-non-empty = true;
            allow-other = true;
            buffer-size = "256M";
            cache-dir = "/home/${config.home.username}/.cache/rclone";
            vfs-cache-mode = "full";
            vfs-read-chunk-size = "128M";
            vfs-read-chunk-size-limit = "1G";
            # Additional stability options
            dir-cache-time = "5000h";
            poll-interval = "15s";
            # Reduce memory usage
            vfs-cache-max-age = "1h";
            vfs-cache-max-size = "1G";
            # Permissions
            umask = "000";
            gid = "100"; # Users group
          };
        };
      };
    };
  };

  sops.secrets = {
    "rclone/client-secret" = {};
    "rclone/token" = {};
  };

  systemd.user = {
    startServices = "sd-switch"; # https://home-manager-options.extranix.com/?query=rclone&release=master

    # Ensure mount directory exists with correct permissions
    tmpfiles.rules = [
      "d ${mountdir} 0755 ${config.home.username} users -"
    ];
  };
}
