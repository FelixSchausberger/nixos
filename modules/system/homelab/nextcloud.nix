{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.nextcloud;
in {
  options.modules.system.homelab.nextcloud = {
    enable = lib.mkEnableOption "Nextcloud file sync and share server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/nextcloud";
      description = "Path for Nextcloud data directory";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "HTTP port for Nextcloud web UI";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for Nextcloud server";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Nextcloud HTTP port";
    };
    externalStorage = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name in Nextcloud";
            };
            path = lib.mkOption {
              type = lib.types.str;
              description = "Local filesystem path to expose";
            };
          };
        }
      );
      default = [
        {
          name = "Obsidian";
          path = "/per/mnt/data/Obsidian";
        }
        {
          name = "Documents";
          path = "/per/mnt/data/Documents";
        }
        {
          name = "Books";
          path = "/per/mnt/data/Books";
        }
      ];
      description = "Local directories exposed as Nextcloud external storage via files_external";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      enable = true;
      hostName = "nextcloud.local";
      package = pkgs.nextcloud33;
      datadir = cfg.dataPath;
      config = {
        dbtype = "pgsql";
        dbname = "nextcloud";
        dbhost = "localhost";
        dbuser = "nextcloud";
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nextcloud/admin-password".path;
      };
      settings = {
        trusted_domains = [
          "nextcloud.local"
          "localhost"
          "127.0.0.1"
          "192.168.178.2"
          "100.105.37.12"
        ];
      };
      maxUploadSize = "16G";
      https = false;
      configureRedis = true;
      autoUpdateApps.enable = true;
    };

    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts."nextcloud.local" = {
        listen = lib.mkForce [
          {
            addr = cfg.host;
            inherit (cfg) port;
          }
        ];
      };
    };

    systemd.services.phpfpm-nextcloud.serviceConfig = {
      MemoryMax = "2G";
      MemoryHigh = "1.5G";
      CPUQuota = "100%";
    };

    systemd.services.nextcloud-cron.serviceConfig = {
      MemoryMax = "1G";
      MemoryHigh = "768M";
      CPUQuota = "50%";
    };

    systemd.services.nextcloud-update-plugins = {
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
    };

    systemd.services.nextcloud-setup = {
      after = [
        "systemd-tmpfiles-setup.service"
        "postgresql-setup.service"
      ];
      requires = ["postgresql-setup.service"];
      unitConfig = {
        StartLimitBurst = 3;
        StartLimitIntervalSec = 60;
      };
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = ["nextcloud"];
      ensureUsers = [
        {
          name = "nextcloud";
          ensureDBOwnership = true;
        }
      ];
      authentication = ''
        local all nextcloud trust
        host all nextcloud 127.0.0.1/32 trust
        host all nextcloud ::1/128 trust
        local all all ident
        host all all 127.0.0.1/32 ident
      '';
    };

    sops.secrets."nextcloud/admin-password" = {
      owner = "nextcloud";
      group = "nextcloud";
      mode = "0440";
    };

    systemd.tmpfiles.rules = let
      aclRules = map (m: "a+ ${m.path} - - - - u:nextcloud:rx,d:u:nextcloud:rx") cfg.externalStorage;
    in
      [
        "d ${cfg.dataPath} 0750 nextcloud nextcloud -"
        "d ${cfg.dataPath}/config 0750 nextcloud nextcloud -"
        "d ${cfg.dataPath}/data 0750 nextcloud nextcloud -"
      ]
      ++ aclRules;

    systemd.services.nextcloud-external-storage = {
      after = ["nextcloud-setup.service"];
      requires = ["nextcloud-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        occ = lib.getExe config.services.nextcloud.occ;
        setfacl = lib.getExe' pkgs.acl "setfacl";
        mountScripts = lib.concatStringsSep "\n" (
          map (m: ''
            echo "Configuring external storage: ${m.name} (${m.path})"
            ${setfacl} -R -m u:nextcloud:rx,d:u:nextcloud:rx ${m.path}
            ${occ} files_external:create \
              "${m.name}" \
              "local" \
              "null::null" \
              -c datadir="${m.path}" || true
          '')
          cfg.externalStorage
        );
      in ''
        set -euo pipefail
        echo "Enabling files_external app..."
        ${occ} app:enable files_external
        ${mountScripts}
        echo "Scanning files into Nextcloud file cache..."
        ADMIN_USER=$(${occ} user:list 2>/dev/null | head -1 | grep -oP '-\s+\K\S+' || echo "admin")
        ${occ} files:scan "$ADMIN_USER" 2>&1 || true
        echo "Nextcloud external storage configured."
      '';
    };

    systemd.services.nextcloud-scan-external = {
      description = "Scan Nextcloud external storage mounts for filesystem changes";
      after = ["nextcloud-setup.service"];
      serviceConfig = {
        Type = "oneshot";
      };
      script = let
        occ = lib.getExe config.services.nextcloud.occ;
        scanPaths = lib.concatStringsSep "\n" (
          map (m: ''
            echo "Scanning ${m.name}..."
            ${occ} files:scan admin --path "/admin/files/${m.name}" 2>&1 || true
          '')
          cfg.externalStorage
        );
      in ''
        set -euo pipefail
        ${scanPaths}
        echo "Scan complete."
      '';
    };

    systemd.paths.nextcloud-scan-external = {
      wantedBy = ["multi-user.target"];
      pathConfig.PathModified = map (m: m.path) cfg.externalStorage;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    environment.persistence."/per".directories = [
      "/var/lib/nextcloud"
      "/var/lib/nginx"
    ];
  };
}
