{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.calibreWeb;
  inherit (lib) mkIf mkEnableOption mkOption types;

  # Werkzeug generates the admin password hash in the same format
  # (pbkdf2:sha256 / scrypt) the app validates against; the password itself
  # never leaves the sops secret file.
  calibreWebHashGen = pkgs.python3.withPackages (ps: [ps.werkzeug]);
in {
  options.modules.system.homelab.calibreWeb = {
    enable = mkEnableOption "Calibre-Web ebook library server with Kobo sync and kepub conversion";

    libraryPath = mkOption {
      type = types.str;
      default = "/per/mnt/data/media/books";
      description = ''
        Calibre library root (metadata.db plus author/title book tree) served
        by Calibre-Web. Books sit next to the Navidrome music tree under
        media/ (user-curated media), stay browsable through the Samba data
        share, and are covered by the dpool/data sanoid snapshots. A plain
        string, like the other data-path options: the upstream module's
        calibreLibrary option is typed path, and a path value outside the
        store is forbidden under comin's pure evaluation.
      '';
    };

    dataPath = mkOption {
      type = types.str;
      default = "/per/mnt/data/services/calibre-web";
      description = ''
        App state directory (app.db: users, Kobo sync keys, UI settings).
        Lives under the services/ domain split like nextcloud and immich.
      '';
    };

    port = mkOption {
      type = types.port;
      default = inputs.self.lib.homelabPorts.calibreWeb;
      description = "HTTP port for the Calibre-Web web UI, OPDS and Kobo sync";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open the firewall for the HTTP port. Required for Kobo sync: the
        device must reach the server directly over the LAN (it cannot run
        Tailscale), and the Kobo sync protocol runs over plain HTTP.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.calibre-web = {
      enable = true;
      dataDir = cfg.dataPath;
      inherit (cfg) openFirewall;
      listen = {
        # The LAN must reach the service for Kobo sync; loopback alone only
        # serves the Caddy route (bind 0.0.0.0 covers both).
        ip = mkIf cfg.openFirewall "0.0.0.0";
        inherit (cfg) port;
      };
      options = {
        # Left null deliberately: the upstream option is typed path, which
        # pure evaluation forbids for runtime paths. The library dir is
        # seeded into app.db by calibre-web-init below instead, and the
        # unit's ReadWritePaths grant comes from this module as a string.
        calibreLibrary = null;
        # kepubify converts to Kobo's kepub format on the fly during Kobo
        # sync and downloads - no pre-converted library copies needed.
        enableKepubify = true;
        # Web UI upload replaces the old ingest-folder flow: books arrive by
        # upload with their embedded epub metadata (title/author/cover).
        enableBookUploading = true;
      };
    };

    # The upstream ReadWritePaths only covers the library when the
    # path-typed calibreLibrary option is set; with it null,
    # ProtectSystem=strict would block every write to the library.
    systemd.services.calibre-web.serviceConfig.ReadWritePaths = [cfg.libraryPath];

    sops.secrets."calibre-web/admin-password" = {
      owner = "calibre-web";
      group = "calibre-web";
      mode = "0400";
    };

    # The service user is neither the file owner nor in sambashare, so the
    # library needs ACLs like the Navidrome music tree: rwX for the service
    # user and for the Samba share group (the data share already grants
    # group write at the share level, so this only makes local access
    # consistent with it). Default ACLs cover everything created afterwards:
    # files by the service (uploads), books by local calibredb imports.
    # Files moved in externally keep their own modes and need
    # `setfacl -R -m u:calibre-web:rwX,d:u:calibre-web:rwX <library>` after
    # the fact.
    systemd.tmpfiles.rules = let
      user = config.services.calibre-web.user;
    in [
      "d ${cfg.libraryPath} 0775 root sambashare -"
      "a+ ${cfg.libraryPath} - - - - u:${user}:rwX,d:u:${user}:rwX,g:sambashare:rwX,d:g:sambashare:rwX"
    ];

    # One-shot library bootstrap. The upstream pre-start check hard-fails the
    # unit while metadata.db is missing, which crash-loops from first deploy
    # until a first import creates the library, and the library path cannot
    # ride the upstream option (typed path, see above). This unit:
    #   1. initializes an empty Calibre database via `calibredb list` when
    #      metadata.db is absent,
    #   2. runs the app's migration entrypoint once (the same
    #      __RUN_MIGRATIONS_AND_EXIT call the upstream ExecStartPre makes,
    #      idempotent) so app.db exists,
    #   3. seeds config_calibre_dir and the sops-managed admin password into
    #      app.db, the declarative replacement for the upstream option.
    # Everything runs as the service user, so app.db, metadata.db and later
    # uploads all start life with the tmpfiles default ACLs.
    systemd.services.calibre-web-init = {
      description = "Initialize Calibre library and app state for Calibre-Web";
      requiredBy = ["calibre-web.service"];
      before = ["calibre-web.service"];
      environment = {CACHE_DIR = "/var/cache/calibre-web";};
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.calibre-web.user;
        Group = config.services.calibre-web.group;
        CacheDirectory = "calibre-web";
        ExecStart = pkgs.writeShellScript "calibre-web-init" ''
          if [ ! -f ${cfg.libraryPath}/metadata.db ]; then
            echo "Initializing empty Calibre library at ${cfg.libraryPath}"
            ${config.services.calibre-web.calibrePackage}/bin/calibredb list --with-library ${cfg.libraryPath}
          else
            echo "Calibre library already initialized"
          fi
          export __RUN_MIGRATIONS_AND_EXIT=1
          ${config.services.calibre-web.package}/bin/calibre-web -p ${cfg.dataPath}/app.db -g ${cfg.dataPath}/gdrive.db
          # The admin password is sops-managed and re-applied on every boot,
          # so a rotation in sops follows on the next deploy; UI-side
          # password changes are overwritten again on the next activation.
          # The hash format is self-describing (werkzeug's own scrypt /
          # pbkdf2 encoding), so the app's check_password_hash validates it.
          _hash=$(${calibreWebHashGen}/bin/python -c '
            from werkzeug.security import generate_password_hash
            with open("${config.sops.secrets."calibre-web/admin-password".path}") as f:
                print(generate_password_hash(f.read().strip()))')
          ${pkgs.sqlite}/bin/sqlite3 ${cfg.dataPath}/app.db \
            "update settings set config_calibre_dir = '${cfg.libraryPath}'"
          ${pkgs.sqlite}/bin/sqlite3 ${cfg.dataPath}/app.db \
            "update user set password = '$_hash' where name = 'admin'"
        '';
      };
    };

    # The per-user "Enable Kobo sync" toggle stays a UI action (app.db): it
    # generates the remote_auth_token that the Kobo's api_endpoint points
    # at, which cannot be known declaratively.
  };
}
