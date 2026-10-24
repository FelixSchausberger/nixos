{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.nextcloud;

  # Obsidian's workspace.json is per-device UI state that every instance
  # rewrites constantly, so keeping it in the desktop sync set churns
  # "(conflicted copy ...)" renames whenever a client races a server-side
  # change. Nextcloud Desktop loads .sync-exclude.lst from its folder sync
  # root at discovery time (this account root is every client's sync root)
  # and excluded entries stay per-device forever after. The mount-root
  # copies cover connections rooted at an external mount instead.
  syncExcludesFile = pkgs.writeText "sync-exclude.lst" ''
    # Planted by the NixOS nextcloud module. Patterns match basenames at
    # any depth below the sync root.
    workspace.json
  '';
in {
  options.modules.system.homelab.nextcloud = {
    enable = lib.mkEnableOption "Nextcloud file sync and share server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/services/nextcloud";
      description = "Path for Nextcloud data directory";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.nextcloud;
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
          path = "/per/mnt/data/notes";
        }
        {
          name = "Documents";
          path = "/per/mnt/data/documents";
        }
        {
          name = "Books";
          path = "/per/mnt/data/documents/books";
        }
        {
          name = "CAD";
          path = "/per/mnt/data/projects/cad";
        }
        {
          name = "Inbox";
          path = "/per/mnt/data/inbox";
        }
      ];
      description = "Local directories exposed as Nextcloud external storage via files_external";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      enable = true;
      hostName = "nextcloud.local";
      # Nextcloud only upgrades one major version at a time and the NixOS
      # module runs `occ upgrade` during activation, so this package stays
      # one step behind the newest nixpkgs major: bump it once the target
      # upgrade has completed successfully (occ status shows the new
      # versionstring with needsDbUpgrade false). The instance is on 35,
      # 34 having run clean;
      package = pkgs.nextcloud35;
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

        # Caddy terminates TLS and proxies over loopback, so nginx and PHP-FPM
        # present 127.0.0.1 as the peer for every request. Without
        # trusted_proxies Nextcloud throttles that one shared address, which
        # slows down every client at once, and rejects the X-Forwarded-*
        # headers Caddy sends as spoofable. Trusting loopback is safe here:
        # Caddy replaces (does not append) X-Forwarded-For for peers outside
        # its own trusted_proxies, and nginx listens on loopback only, so no
        # external client can reach the FastCGI hop with a forged header.
        trusted_proxies = ["127.0.0.1"];

        # Profile phone numbers are validated against this region when the
        # user omits a country code.
        default_phone_region = "AT";

        # A single PHP pool serves this instance, so the ID only needs to be
        # valid (0-511); it shards cache keys when several pools share one
        # instance and the setup check reports its absence otherwise.
        serverid = 1;

        # Public profile pages stay off: this is a single-account file sync
        # backend and a profile page would publish the account to the network.
        profile.enabled = false;

        # New accounts start with an empty home; the shipped skeleton files
        # are noise on a personal instance.
        skeletondirectory = "";

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

        # Outgoing mail goes through Gmail over SSL on 465, authenticating as
        # the account itself. Gmail refuses plain password auth unless the
        # account has 2FA, so the password is a 16-character app password.
        # The password is the one setting left out: services.nextcloud.settings
        # is rendered into the world-readable nix store, so the credential is
        # entered once in the admin UI and persists in config.php in the
        # datadir.
        mail_smtpmode = "smtp";
        mail_smtphost = "smtp.gmail.com";
        mail_smtpport = 465;
        mail_smtpsecure = "ssl";
        mail_smtpauth = true;
        mail_smtpname = "fel.schausberger@gmail.com";
        mail_from_address = "fel.schausberger";
        mail_domain = "gmail.com";

        # Run maintenance (DB migrations, scans) outside active hours.
        maintenance_window_start = 1;
        # Route Nextcloud's PHP log to journald (journalctl -t Nextcloud).
        log_type = "systemd";
      };
      maxUploadSize = "16G";
      https = false;
      configureRedis = true;
      # Store apps are not part of this install (appstoreenabled=false and
      # every extraApp rides the package), so the store updater has nothing
      # to do: occ app:update --all aborts on each timer run otherwise.
      autoUpdateApps.enable = false;

      extraApps = {
        # Apps follow the configured package version, so a Nextcloud major
        # upgrade only requires changing `services.nextcloud.package`.
        inherit
          (config.services.nextcloud.package.packages.apps)
          calendar
          contacts
          previewgenerator
          tasks
          ;
      };
      extraAppsEnable = true;

      phpOptions = {
        # Disabling PHP's native session upload progress removes the
        # confirmed stale-global-state RCE path of CVE-2026-109619
        # (CERT-EU 2026-018). Nextcloud uploads go through chunked WebDAV,
        # not PHP session upload progress, so nothing here needs it.
        # Pool php.ini is where the PHP team says this must take effect.
        "session.upload_progress.enabled" = "0";
        "opcache.memory_consumption" = "256";
        "opcache.max_accelerated_files" = "20000";
        "opcache.revalidate_freq" = "60";
        # The 8 MB default fills up with Nextcloud's repeated strings (paths,
        # app names), leaving no room to intern more.
        "opcache.interned_strings_buffer" = "16";
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

    # Published share link for the Homepage calendar widget: the token URL
    # is itself the credential (the calendar DAV backend requires auth,
    # this anonymous export path does not).
    sops.secrets."nextcloud/calendar-ics-share-url" = {};

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
      # Runs on a timer too: without one, an external-storage mount deleted
      # through the web UI or the client stayed gone until the next reboot,
      # silently 404ing every consumer of the mount (desktop sync pairs, the
      # rclone WebDAV vault drive). The script is a no-op reconcile, so an
      # interval run is cheap and self-heals exactly that failure mode.
      serviceConfig = {
        Type = "oneshot";
      };
      # Reconcile instead of rebuilding. The previous delete-all/create-all
      # cycle gave every mount a fresh storage signature on every run, which
      # renumbered every file ID below it and invalidated the file-ID cache
      # held by every desktop sync client -- surfacing as sync conflicts on
      # the Windows box. A mount whose datadir already matches the declared
      # config is now left alone, so this is a no-op after an unrelated
      # deploy, and a path change only renumbers the one mount that moved.
      script = let
        occ = lib.getExe config.services.nextcloud.occ;
        jq = lib.getExe' pkgs.jq "jq";
        setfacl = lib.getExe' pkgs.acl "setfacl";

        # files_external:create normalises its argument to a leading-slash
        # mount_point, so match on that normalised form.
        mountPoint = m: "/${m.name}";

        # Apply ACLs, then keep an already-correct mount or recreate one.
        ensureMount = m: ''
          echo "Ensuring external storage: ${m.name} (${m.path})"
          ${setfacl} -R -m u:nextcloud:rwx,d:u:nextcloud:rwx ${m.path}
          _id="$(${jq} -r --arg mp "${mountPoint m}" \
            '[.[] | select(.mount_point == $mp) | .mount_id][0] // empty' <<<"$_mounts")"
          _dir="$(${jq} -r --arg mp "${mountPoint m}" \
            '[.[] | select(.mount_point == $mp) | .configuration.datadir][0] // empty' <<<"$_mounts")"
          if [ -n "$_id" ] && [ "$_dir" = "${m.path}" ]; then
            echo "    unchanged (mount_id $_id)"
          else
            if [ -n "$_id" ]; then
              echo "    datadir changed ($_dir -> ${m.path}); recreating"
              ${occ} files_external:delete "$_id" --yes
            fi
            ${occ} files_external:create "${m.name}" "local" "null::null" -c datadir="${m.path}"
            _mounts="$(${occ} files_external:list --output json)"
          fi
        '';

        declaredMounts = builtins.toJSON (map mountPoint cfg.externalStorage);
      in ''
        set -euo pipefail
        echo "Enabling files_external app..."
        ${occ} app:enable files_external

        echo "Reconciling external storage mounts..."
        _mounts="$(${occ} files_external:list --output json)"

        # Retire mounts the configuration no longer declares.
        ${jq} -r --argjson keep '${declaredMounts}' \
          '.[] | select(.mount_point as $p | ($keep | index($p)) == null) | .mount_id' \
          <<<"$_mounts" \
          | while read -r _id; do
              [ -n "$_id" ] || continue
              echo "    removing undeclared mount_id $_id"
              ${occ} files_external:delete "$_id" --yes
            done
        _mounts="$(${occ} files_external:list --output json)"

        ${lib.concatMapStringsSep "\n" ensureMount cfg.externalStorage}

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

    # The mount reconcile is also a timer: without one, an external-storage
    # mount deleted through the web UI or a client stayed gone until the next
    # reboot, silently 404ing every consumer of the mount (desktop sync pairs
    # and the rclone WebDAV vault drive). The script is a no-op reconcile, so
    # the interval is cheap and self-heals exactly that failure mode.
    systemd.timers.nextcloud-external-storage = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "15min";
        RandomizedDelaySec = "5min";
      };
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

    # The embedded store path keeps this unit restart-on-switch: any
    # exclusion change re-installs the files on the next apply.
    systemd.services.nextcloud-sync-excludes = {
      description = "Install Nextcloud client sync exclusion lists";
      after = ["nextcloud-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (
        map
        # External storage mounts hold foreign content owned by the user
        # via ACLs; the copied file itself is owned by nextcloud so the
        # scanner can read it.
        (
          p: ''
            install -m0644 ${syncExcludesFile} "${p}/.sync-exclude.lst"
            chown nextcloud:nextcloud "${p}/.sync-exclude.lst"
          ''
        )
        (
          ["${cfg.dataPath}/data/admin/files"]
          ++ map (m: m.path) cfg.externalStorage
        )
      );
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    environment.persistence."/per".directories = [
      "/var/lib/nextcloud"
      "/var/lib/nginx"
    ];
  };
}
