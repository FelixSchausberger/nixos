{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.immich;

  # Returns tmpfiles rules for a subdirectory, using a symlink if fastPath is set,
  # otherwise a plain directory. Immich follows symlinks transparently.
  subdir = name: fastPath: let
    target =
      if fastPath != null
      then fastPath
      else "${cfg.dataPath}/${name}";
  in
    lib.optionals (fastPath != null) [
      "d ${fastPath} 0700 immich immich -"
      "f ${fastPath}/.immich 0600 immich immich - immich"
      # Remove existing directory if present before creating symlink (L+ replaces)
      "L+ ${cfg.dataPath}/${name} - - - - ${fastPath}"
    ]
    ++ lib.optionals (fastPath == null) [
      "d ${target} 0700 immich immich -"
      "f ${target}/.immich 0600 immich immich - immich"
    ];
in {
  options.modules.system.homelab.immich = {
    enable = lib.mkEnableOption "Immich photo backup server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/immich";
      description = "Path for Immich media library (library/, upload/, profile/, backups/)";
    };
    thumbsPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Override path for the thumbs/ subdirectory. When set, a symlink is
        created at dataPath/thumbs pointing here. Use a fast NVMe path to
        avoid random-read latency on slow SATA drives during timeline scrolling.
      '';
    };
    encodedVideoPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Override path for the encoded-video/ subdirectory. When set, a symlink
        is created at dataPath/encoded-video pointing here.
      '';
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "HTTP port for Immich web UI";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for Immich server";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Immich HTTP port";
    };
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      inherit (cfg) host;
      inherit (cfg) port;
      mediaLocation = cfg.dataPath;
      inherit (cfg) openFirewall;
      environment.IMMICH_METRICS = "true";
    };

    # Thumbnail serving is CPU-bound; 3 cores prevents request queuing under load.
    # Memory limits sized for 16GB host leaving headroom for ZFS ARC and other services.
    # BindReadOnlyPaths exposes the external photo library at a path outside
    # IMMICH_MEDIA_LOCATION so Immich's isImmichPath() check passes, allowing it
    # to be configured as an external library import path.
    systemd.services.immich-server.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
      CPUQuota = "300%";
      BindReadOnlyPaths = ["/per/mnt/data/immich-library"];
    };

    # ML inference runs during photo analysis, not during normal browsing.
    systemd.services.immich-machine-learning.serviceConfig = {
      MemoryMax = "6G";
      MemoryHigh = "5G";
      CPUQuota = "200%";
    };

    sops.secrets."immich/admin-password" = {
      owner = "immich";
    };

    systemd.timers.immich-admin-setup = {
      description = "Timer for Immich admin user creation (non-blocking)";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
      };
    };

    systemd.services.immich-admin-setup = {
      description = "Create Immich admin user from sops secret";
      after = [
        "immich-server.service"
        "sops-nix.service"
      ];
      wants = ["immich-server.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "immich";
      };
      script = ''
        PASSWORD=$(cat ${config.sops.secrets."immich/admin-password".path})
        PORT=${toString cfg.port}

        HTTP_CODE=$(${lib.getExe pkgs.curl} -s -o /dev/null -w "%{http_code}" \
          -X POST http://localhost:$PORT/api/auth/admin-sign-up \
          -H "Content-Type: application/json" \
          -d "{\"email\":\"fel.schausberger@gmail.com\",\"name\":\"Felix\",\"password\":\"$PASSWORD\"}")

        case "$HTTP_CODE" in
          201)
            ${lib.getExe' pkgs.postgresql "psql"} -h /run/postgresql -d immich -c \
              "UPDATE \"user\" SET \"shouldChangePassword\"=false WHERE email='fel.schausberger@gmail.com';"
            ;;
          400|409)
            exit 0
            ;;
          *)
            echo "Unexpected HTTP response from admin-sign-up: $HTTP_CODE"
            exit 1
            ;;
        esac
      '';
    };
    systemd.tmpfiles.rules =
      [
        "d ${cfg.dataPath} 0700 immich immich -"
        "d ${cfg.dataPath}/backups 0700 immich immich -"
        "d ${cfg.dataPath}/library 0700 immich immich -"
        "d ${cfg.dataPath}/profile 0700 immich immich -"
        "d ${cfg.dataPath}/upload 0700 immich immich -"
        "f ${cfg.dataPath}/backups/.immich 0600 immich immich - immich"
        "f ${cfg.dataPath}/library/.immich 0600 immich immich - immich"
        "f ${cfg.dataPath}/profile/.immich 0600 immich immich - immich"
        "f ${cfg.dataPath}/upload/.immich 0600 immich immich - immich"
        # Symlink outside IMMICH_MEDIA_LOCATION so Immich's isImmichPath() check passes,
        # allowing this path to be configured as an external library import path.
        "d /per/mnt/data/immich-library 0755 root root -"
        "L /per/mnt/data/immich-library/admin - - - - ${cfg.dataPath}/library/admin"
      ]
      ++ subdir "thumbs" cfg.thumbsPath
      ++ subdir "encoded-video" cfg.encodedVideoPath;

    environment.persistence."/per".directories = [
      "/var/lib/immich"
    ];
  };
}
