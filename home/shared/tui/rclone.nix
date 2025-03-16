{
  config,
  inputs,
  pkgs,
  ...
}: let
  mountdir = "/per/mnt/gdrive";
in {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];
  systemd.user.services.gdrive_mount = {
    Unit = {
      Description = "mount gdrive dirs";
      After = ["network-online.target"];
    };
    Install.WantedBy = ["graphical-session.target"];
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountdir}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount \
            --drive-client-id "${config.sops.secrets."rclone/client-id".path}" \
            --drive-client-secret "${config.sops.secrets."rclone/client-secret".path}" gdrive: ${mountdir} \
              --dir-cache-time 48h \
              --vfs-cache-mode full \
              --vfs-cache-max-age 48h \
              --vfs-read-chunk-size 10M \
              --vfs-read-chunk-size-limit 512M \
              --buffer-size 512M
      '';
      ExecStop = "/run/wrappers/bin/fusermount -u ${mountdir}";
      Type = "notify";
      Restart = "always";
      RestartSec = "10s";
      Environment = ["PATH=/run/wrappers/bin/:$PATH"];
    };
  };

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".config/rclone";
        method = "symlink";
      }
    ];
  };
}
