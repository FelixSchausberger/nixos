{
  config,
  pkgs,
  ...
}: let
  mountdir = "/per/mnt/gdrive";
  setupScript = pkgs.writeShellScript "setup-rclone" ''
      mkdir -p ${config.xdg.configHome}/rclone
      ${pkgs.coreutils}/bin/cat > ${config.xdg.configHome}/rclone/rclone.conf << EOF
    [gdrive]
    type = drive
    scope = drive
    root_folder_id = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/root-id".path})
    client_id = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/client-id".path})
    client_secret = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/client-secret".path})
    token = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/token".path})
    config_is_local = true
    disable_http2 = true
    EOF
  '';
  cleanupScript = pkgs.writeShellScript "cleanup-mount" ''
    # Check if the mount is stale
    if mountpoint -q ${mountdir} || grep -q "${mountdir}" /proc/mounts; then
      # Try to unmount it cleanly
      fusermount -u ${mountdir} 2>/dev/null || umount -f ${mountdir} 2>/dev/null || true
    fi

    # Recreate the directory structure
    rm -rf ${mountdir} 2>/dev/null || true
    mkdir -p /per/mnt
    mkdir -p ${mountdir}
  '';
in {
  programs.rclone = {
    enable = true;
    package = pkgs.rclone;
  };

  sops.secrets = {
    "rclone/client-id" = {};
    "rclone/client-secret" = {};
    "rclone/token" = {};
    "rclone/root-id" = {};
  };

  systemd.user.services.gdrive-mount = {
    Unit = {
      Description = "Google Drive Mount";
      After = ["sops-nix.service"];
      Requires = ["sops-nix.service"];
    };

    Service = {
      Type = "notify";
      ExecStartPre = [
        "${cleanupScript}"
        "${setupScript}"
      ];
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
      ExecStop = "${pkgs.util-linux}/bin/umount -f ${mountdir} || true";
      Restart = "on-failure";
      RestartSec = "30s";
    };

    Install = {
      WantedBy = ["default.target"];
    };
  };
}
