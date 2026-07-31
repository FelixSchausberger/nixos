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
      # Pinned to nextcloud33 for the staged upgrade path on this pre-26.11
      # install: NixOS requires one major version step at a time. After 33 has
      # run successfully, bump to `pkgs.nextcloud34`; `occ upgrade` runs
      # automatically during activation. nextcloud33 is removed from nixpkgs
      # once unsupported upstream.
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
        trusted_domains =
          [
            "nextcloud.local"
            "localhost"
            "127.0.0.1"
            "192.168.178.2"
            "100.105.37.12"
          ]
          # Allow access via the Caddy Tailscale reverse proxy when enabled.
          ++ lib.optionals config.modules.system.homelab.caddyProxy.enable [
            config.modules.system.homelab.caddyProxy.tailnetDomain
          ];

        # When Caddy serves Nextcloud at /nextcloud, these settings ensure
        # Nextcloud generates correct URLs and WebDAV paths. overwriteprotocol
        # forces HTTPS since Caddy terminates TLS and Nextcloud sees plain HTTP;
        # overwrite.cli.url keeps occ-generated URLs (notifications, link
        # shares) pointing at the public Tailscale address.
        overwritewebroot = lib.mkIf config.modules.system.homelab.caddyProxy.enable "/nextcloud";
        overwriteprotocol = lib.mkIf config.modules.system.homelab.caddyProxy.enable "https";
        overwrite.cli.url =
          lib.mkIf config.modules.system.homelab.caddyProxy.enable
          "https://${config.modules.system.homelab.caddyProxy.tailnetDomain}/nextcloud/";

        # Run maintenance (DB migrations, scans) outside active hours.
        maintenance_window_start = 1;
        # Route Nextcloud's PHP log to journald (journalctl -t Nextcloud).
        log_type = "systemd";
      };
      maxUploadSize = "16G";
      https = false;
      configureRedis = true;
      autoUpdateApps.enable = true;

      extraApps = {
        # Apps follow the configured package version, so a Nextcloud major
        # upgrade only requires changing `services.nextcloud.package`.
        inherit
          (config.services.nextcloud.package.packages.apps)
          calendar
          contacts
          tasks
          ;
      };
      extraAppsEnable = true;

      phpOptions = {
        "opcache.memory_consumption" = "256";
        "opcache.max_accelerated_files" = "20000";
        "opcache.revalidate_freq" = "60";
      };

      poolSettings = {
        "pm" = "dynamic";
        "pm.max_children" = "20";
        "pm.max_requests" = "500";
        "pm.start_servers" = "4";
        "pm.min_spare_servers" = "2";
        "pm.max_spare_servers" = "6";
      };
    };

    services.redis.servers.nextcloud.settings = {
      maxmemory = "256mb";
      # noeviction ensures Redis never silently drops file-lock keys under memory pressure.
      # allkeys-lru would evict active locks, causing Obsidian save conflicts.
      "maxmemory-policy" = "noeviction";
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
      CPUQuota = "300%";
    };

    systemd.services.nextcloud-cron.serviceConfig = {
      MemoryMax = "512M";
      MemoryHigh = "384M";
      CPUQuota = "50%";
    };

    systemd.services.nextcloud-update-plugins = {
      after = [
        "postgresql.service"
        "network-online.target"
      ];
      requires = ["postgresql.service"];
      wants = ["network-online.target"];
      serviceConfig = {
        TimeoutStartSec = 180;
        Nice = 19;
        IOSchedulingClass = "idle";
      };
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
      aclRules = map (m: "a+ ${m.path} - - - - u:nextcloud:rwx,d:u:nextcloud:rwx") cfg.externalStorage;
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
        jq = lib.getExe' pkgs.jq "jq";
        setfacl = lib.getExe' pkgs.acl "setfacl";
        deleteExisting = ''
          echo "Removing all existing external storage mounts..."
          ${occ} files_external:list --output json \
            | ${jq} -r '.[].mount_id' \
            | while read -r id; do
                ${occ} files_external:delete "$id" --yes
              done
        '';
        mountScripts = lib.concatStringsSep "\n" (
          map (m: ''
            echo "Configuring external storage: ${m.name} (${m.path})"
            ${setfacl} -R -m u:nextcloud:rwx,d:u:nextcloud:rwx ${m.path}
            ${occ} files_external:create \
              "${m.name}" \
              "local" \
              "null::null" \
              -c datadir="${m.path}"
          '')
          cfg.externalStorage
        );
      in ''
        set -euo pipefail
        echo "Enabling files_external app..."
        ${occ} app:enable files_external
        ${deleteExisting}
        ${mountScripts}
        echo "Scanning files into Nextcloud file cache..."
        ${occ} files:scan admin 2>&1 || true
        echo "Cleaning up orphaned file cache entries..."
        ${occ} files:cleanup 2>&1 || true
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

    systemd.timers.nextcloud-scan-external = {
      description = "Periodic scan of Nextcloud external storage";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        # 1h reduces file-lock contention during active Obsidian editing sessions.
        OnUnitActiveSec = "1h";
      };
    };

    systemd.services.nextcloud-cleanup = {
      description = "Clean up orphaned Nextcloud file cache entries";
      after = ["nextcloud-setup.service"];
      serviceConfig = {
        Type = "oneshot";
      };
      script = let
        occ = lib.getExe config.services.nextcloud.occ;
      in ''
        set -euo pipefail
        echo "Running Nextcloud database maintenance..."
        ${occ} maintenance:repair 2>&1 || true
        echo "Cleaning up orphaned file cache entries..."
        ${occ} files:cleanup 2>&1 || true
        echo "Nextcloud cleanup complete."
      '';
    };

    systemd.timers.nextcloud-cleanup = {
      description = "Weekly Nextcloud file cache cleanup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    environment.persistence."/per".directories = [
      "/var/lib/nextcloud"
      "/var/lib/nginx"
    ];
  };
}
