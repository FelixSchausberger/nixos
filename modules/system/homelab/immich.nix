{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.immich;
in {
  options.modules.system.homelab.immich = {
    enable = lib.mkEnableOption "Immich photo backup server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/immich";
      description = "Path for Immich media library";
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

    systemd.services.immich-server.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1.5G";
      CPUQuota = "100%";
    };

    systemd.services.immich-machine-learning.serviceConfig = {
      MemoryMax = "4G";
      MemoryHigh = "3G";
      CPUQuota = "150%";
    };

    sops.secrets."immich/admin-password" = {
      owner = "immich";
    };

    systemd.services.immich-admin-setup = {
      description = "Create Immich admin user from sops secret";
      after = [
        "immich-server.service"
        "sops-nix.service"
      ];
      wants = ["immich-server.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "immich";
        RemainAfterExit = true;
      };
      script = ''
        PASSWORD=$(cat ${config.sops.secrets."immich/admin-password".path})
        PORT=${toString cfg.port}

        # Wait for immich-server to be ready before attempting sign-up
        for i in $(seq 1 30); do
          HEALTH=$(${lib.getExe pkgs.curl} -s -o /dev/null -w "%{http_code}" \
            http://localhost:$PORT/api/server-info/version 2>/dev/null || echo "000")
          if [ "$HEALTH" = "200" ]; then
            break
          fi
          sleep 2
        done

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

    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0700 immich immich -"
      "d ${cfg.dataPath}/backups 0700 immich immich -"
      "d ${cfg.dataPath}/encoded-video 0700 immich immich -"
      "d ${cfg.dataPath}/library 0700 immich immich -"
      "d ${cfg.dataPath}/profile 0700 immich immich -"
      "d ${cfg.dataPath}/thumbs 0700 immich immich -"
      "d ${cfg.dataPath}/upload 0700 immich immich -"
      "f ${cfg.dataPath}/backups/.immich 0600 immich immich - immich"
      "f ${cfg.dataPath}/encoded-video/.immich 0600 immich immich - immich"
      "f ${cfg.dataPath}/library/.immich 0600 immich immich - immich"
      "f ${cfg.dataPath}/profile/.immich 0600 immich immich - immich"
      "f ${cfg.dataPath}/thumbs/.immich 0600 immich immich - immich"
      "f ${cfg.dataPath}/upload/.immich 0600 immich immich - immich"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/immich"
    ];
  };
}
