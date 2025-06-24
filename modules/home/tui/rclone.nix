{config, ...}: let
  mountPoint = "/per/mnt/gdrive";
in {
  sops.secrets = {
    "rclone/token" = {};
    "rclone/client-secret" = {};
  };

  programs.rclone = {
    enable = true;

    remotes = {
      gdrive = {
        config = {
          type = "drive";
          scope = "drive";
          root_folder_id = "0AGsk4MwDWp9HUk9PVA";
          client_id = "1009718778774-dt220ti1a4qpoo1p0u91umdhonavfn6h.apps.googleusercontent.com";
          client_secret = "{client_secret}";
          token = "{token}";
          config_is_local = true;
          disable_http2 = true;
        };

        secrets = {
          client_secret = config.sops.secrets."rclone/client-secret".path;
          token = config.sops.secrets."rclone/token".path;
        };

        mounts = {
          gdrive = {
            enable = true;
            mountPoint = mountPoint;
            options = {
              vfs-cache-mode = "full";
              vfs-read-chunk-size = "128M";
              vfs-read-chunk-size-limit = "1G";
              buffer-size = "256M";
              log-level = "INFO";
            };
          };
        };
      };
    };
  };

  systemd.user = {
    startServices = "sd-switch"; # https://home-manager-options.extranix.com/?query=rclone&release=master
    tmpfiles.rules = [
      "d ${mountPoint} 0755 ${config.home.username} users -"
    ];
  };
}
