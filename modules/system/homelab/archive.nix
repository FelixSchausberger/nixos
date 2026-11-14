# Cold archive: the legacy data that no live dataset owns, served read-only
# from the backup pool, plus the client-side pull onto the desktop.
#
# The archive is root-owned on purpose. Everything else here is verified
# against MANIFEST.sha256, and a user-writable reference copy could be
# rewritten by the same session that "verifies" it. The SMB share is the only
# read path, and it is read-only.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.archive;
  hl = config.modules.system.homelab;
  inherit (inputs.self.lib) defaults;

  # ntfy topic shared by the homelab alerts. The pull side resolves the server
  # by MagicDNS name, same as the vaultwarden DR pull.
  alertUrl = "http://m920q:2586/homelab-alerts";
in {
  options.modules.system.homelab.archive = {
    enable = lib.mkEnableOption "cold archive served read-only over the Samba share";

    path = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/backup/archive";
      description = "Archive root on the backup pool";
    };

    shareName = lib.mkOption {
      type = lib.types.str;
      default = "archive";
      description = "Samba share name for the archive";
    };

    appBackupSources = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        postgresql = "/per/var/backup/postgresql";
        zigbee2mqtt = "/per/var/backup/zigbee2mqtt";
      };
      description = ''
        Service backup directories mirrored into <path>/app/<name>. They are
        unreadable over SMB in place (0700 postgres/zigbee2mqtt), so the
        archive carries a readable copy; that copy is what leaves the chassis.
      '';
    };

    pull = {
      enable = lib.mkEnableOption "client-side pull of the archive onto this host";

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/per/mnt/backup/m920q-archive";
        description = "Local destination; must sit on the backup pool mount";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/run/m920q-archive";
        description = "CIFS mount point for the read-only archive share";
      };

      server = lib.mkOption {
        type = lib.types.str;
        default = "m920q";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "Pull schedule in systemd calendar format";
      };
    };
  };

  config = lib.mkMerge [
    # ---------- server side (m920q) ----------
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = hl.samba.enable;
          message = "modules.system.homelab.archive requires modules.system.homelab.samba.enable (the archive is served through the Samba share)";
        }
      ];

      # Read-only, group-scoped: sambashare is the same group the data share
      # uses, so the desktop's existing credentials work unchanged.
      services.samba.settings.${cfg.shareName} = {
        inherit (cfg) path;
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "no";
        "valid users" = "@sambashare";
        "force group" = "sambashare";
        "hide unreadable" = "yes";
        "vfs objects" = "catia fruit streams_xattr";
      };

      # The live dump directories change daily while the static tree is
      # frozen; keep the mirror and its checksums refreshed after the
      # PostgreSQL (13:40) and Zigbee2MQTT (13:50) timers have run.
      systemd.services.archive-app-sync = {
        description = "Mirror service backups into the cold archive";
        serviceConfig = {
          Type = "oneshot";
          ProtectSystem = "strict";
          PrivateTmp = true;
          ReadWritePaths = ["${cfg.path}/app"];
        };
        script = ''
          set -euo pipefail
          dest=${cfg.path}/app
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
              ${pkgs.rsync}/bin/rsync -a --delete \
                --chown=root:sambashare --chmod=D750,F640 \
                ${src}/ $dest/${name}/
            '')
            cfg.appBackupSources)}
          cd "$dest"
          ${pkgs.findutils}/bin/find . -type f ! -name MANIFEST.sha256 -print0 \
            | sort -z \
            | xargs -0 ${pkgs.coreutils}/bin/sha256sum > MANIFEST.sha256
          chown root:sambashare MANIFEST.sha256
          chmod 0640 MANIFEST.sha256
        '';
      };

      systemd.timers.archive-app-sync = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily 14:10";
          Persistent = true;
        };
      };
    })

    # ---------- pull side (desktop) ----------
    (lib.mkIf cfg.pull.enable {
      # CIFS credentials rendered from the same Samba secret the DR pull uses.
      sops.secrets."samba/user-password" = {};

      sops.templates."samba-archive-credentials" = {
        content = ''
          username=${defaults.system.user}
          password=${config.sops.placeholder."samba/user-password"}
        '';
        owner = "root";
        mode = "0400";
      };

      # read-only, and mounted on demand: the weekly pull is the only consumer.
      fileSystems.${cfg.pull.mountPoint} = {
        device = "//${cfg.pull.server}/${cfg.shareName}";
        fsType = "cifs";
        options = [
          "credentials=${config.sops.templates."samba-archive-credentials".path}"
          "ro"
          "vers=3.0"
          "uid=0"
          "gid=0"
          "iocharset=utf8"
          "nofail"
          "x-systemd.automount"
          "x-systemd.mount-timeout=30"
        ];
        noCheck = true;
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.pull.mountPoint} 0755 root root -"
        "d ${cfg.pull.directory} 0755 root root -"
      ];

      systemd.services.archive-pull = {
        description = "Pull the m920q cold archive";
        wants = ["network-online.target"];
        after = ["network-online.target"];
        # Start after the CIFS mount is active; without it the mountpoint is
        # an empty directory and --delete would wipe the local copy.
        unitConfig.RequiresMountsFor = [cfg.pull.mountPoint];
        path = with pkgs; [coreutils curl findutils gawk gnugrep rsync util-linux];
        script = ''
          set -o errtrace

          alert() {
            curl -fsS \
              -H "Title: archive pull failed" \
              -H "Tags: warning,minidisc" \
              -d "desktop could not pull the m920q archive: $1" \
              ${alertUrl} >/dev/null 2>&1 || true
          }
          trap 'alert "$BASH_COMMAND"' ERR

          src=${cfg.pull.mountPoint}
          dest=${cfg.pull.directory}

          mountpoint -q "$src" || { alert "share is not mounted (tailnet or Samba down?)"; exit 1; }
          mountpoint -q "$(dirname "$dest")" || { alert "backup pool is not mounted"; exit 1; }

          # The manifest's total is the size oracle; refuse to start a pull
          # that cannot finish.
          need=$(awk '/^TOTAL / {print $4}' "$src/MANIFEST.txt")
          avail=$(df --output=avail -B1 "$(dirname "$dest")" | tail -n1 | tr -d ' ')
          if [ -n "$need" ] && [ "$avail" -lt $(( need + need / 20 )) ]; then
            alert "not enough space: need $need bytes, have $avail"
            exit 1
          fi

          mkdir -p "$dest"
          rsync -a --delete --chown=root:root --chmod=D0755,F0644 "$src/" "$dest/"

          # Verify what landed, not what was read: a truncated transfer shows
          # up here, and the manifest names every file.
          for manifest in MANIFEST.sha256 app/MANIFEST.sha256; do
            [ -f "$dest/$manifest" ] || continue
            ( cd "$dest/$(dirname "$manifest")" && sha256sum -c "$(basename "$manifest")" >/dev/null ) \
              || { alert "checksum mismatch in $manifest"; exit 1; }
          done
        '';
      };

      systemd.timers.archive-pull = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.pull.interval;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
