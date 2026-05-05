{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  mountDir = defaults.paths.mountDirs.gdrive;
  rcloneConfig = "/home/${user}/.config/rclone/rclone.conf";
  cacheDir = "/var/cache/rclone";
  inherit (defaults.system) user;
  root_folder_id = "0AGsk4MwDWp9HUk9PVA";
  client_id = "1009718778774-dt220ti1a4qpoo1p0u91umdhonavfn6h.apps.googleusercontent.com";

  setupScript = pkgs.writeShellScript "setup-rclone-gdrive" ''
    set -euo pipefail

    if [[ ! -f "${config.sops.secrets."rclone/client-secret".path}" ]] || [[ ! -f "${
      config.sops.secrets."rclone/token".path
    }" ]]; then
      echo "Error: Required secrets not found"
      exit 1
    fi

    mkdir -p /home/${user}/.config/rclone
    ${pkgs.coreutils}/bin/cat > ${rcloneConfig} << EOF
    [gdrive]
    type = drive
    scope = drive
    root_folder_id = ${root_folder_id}
    client_id = ${client_id}
    client_secret = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/client-secret".path})
    token = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."rclone/token".path})
    config_is_local = true
    disable_http2 = true
    EOF

    chmod 600 ${rcloneConfig}
  '';
in {
  systemd.services.gdrive-mount = {
    description = "Google Drive FUSE Mount";
    after = ["sops-nix.service"];
    wantedBy = ["multi-user.target"];

    environment = {
      RCLONE_CONFIG = rcloneConfig;
    };

    serviceConfig = {
      Type = "simple";
      ExecStartPre = ["${setupScript}"];

      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount \
          --config=${rcloneConfig} \
          --vfs-cache-mode full \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-size-limit 1G \
          --buffer-size 256M \
          --cache-dir ${cacheDir} \
          --vfs-cache-max-age 1h \
          --vfs-cache-max-size 1G \
          --dir-cache-time 5000h \
          --poll-interval 15s \
          --log-level INFO \
          --allow-other \
          --uid 1000 \
          --gid 100 \
          --umask 002 \
          gdrive: ${mountDir}
      '';

      ExecStop = "${pkgs.util-linux}/bin/umount -f ${mountDir} || true";
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "60s";
      TimeoutStopSec = "30s";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${mountDir} 0755 ${user} users -"
    "d ${cacheDir} 0700 ${user} users -"
    "d /home/${user}/.config/rclone 0700 ${user} users -"
  ];
}
