{
  config,
  pkgs,
  ...
}: let
  mountDir = "/per/mnt/gdrive";
  cacheDir = "/home/${config.home.username}/.cache/rclone";
  root_folder_id = "0AGsk4MwDWp9HUk9PVA";
  client_id = "1009718778774-dt220ti1a4qpoo1p0u91umdhonavfn6h.apps.googleusercontent.com";

  setupScript = pkgs.writeShellScript "setup-rclone" ''
    set -euo pipefail

    # Wait for secrets to be available
    for i in {1..30}; do
      if [[ -f "${config.sops.secrets."rclone/client-secret".path}" ]] && [[ -f "${config.sops.secrets."rclone/token".path}" ]]; then
        break
      fi
      echo "Waiting for secrets to be available... ($i/30)"
      sleep 2
    done

    if [[ ! -f "${config.sops.secrets."rclone/client-secret".path}" ]] || [[ ! -f "${config.sops.secrets."rclone/token".path}" ]]; then
      echo "Error: Required secrets not found after waiting"
      exit 1
    fi

    mkdir -p ${config.xdg.configHome}/rclone
    ${pkgs.coreutils}/bin/cat > ${config.xdg.configHome}/rclone/rclone.conf << EOF
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

    echo "rclone configuration created successfully"
  '';
in {
  programs.rclone.enable = true;

  sops.secrets = {
    "rclone/client-secret" = {};
    "rclone/token" = {};
  };

  systemd.user = {
    services.gdrive-mount = {
      Unit = {
        Description = "Google Drive Mount";
        After = ["sops-nix.service" "sopswarden-sync.service"];
        Wants = ["sops-nix.service"];
      };

      Service = {
        Type = "notify";
        ExecStartPre = ["${setupScript}"];
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount \
            --config=${config.xdg.configHome}/rclone/rclone.conf \
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
            --umask 000 \
            --gid 100 \
            gdrive: ${mountDir}
        '';
        ExecStop = "${pkgs.util-linux}/bin/umount -f ${mountDir} || true";
        Restart = "on-failure";
        RestartSec = "30s";
        TimeoutStartSec = "60s";
        TimeoutStopSec = "30s";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };

    tmpfiles.rules = [
      "d ${mountDir} 0755 ${config.home.username} users -"
      "d ${cacheDir} 0755 ${config.home.username} users -"
    ];
  };
}
