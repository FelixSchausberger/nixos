# Self-hosted Bitwarden-compatible server for the personal vault, consumed
# by rbw in the terminal and the official Bitwarden apps on Android
# (autofill + TOTP). The server itself is tailnet-only: clients reach it
# through a dedicated Tailscale Serve port, the same primitive as
# zellij-web, opencode-web and homepage. A path-routed Caddy prefix is not
# viable — the Bitwarden web vault is a root-served SPA with root-absolute
# asset URLs (the same failure mode documented in homepage.nix), Immich
# already owns the Caddy root catch-all, and Tailscale issues certificates
# only for the exact MagicDNS hostname, never for a subdomain.
#
# DR (dr.*): dpool and bpool/backup both die with the m920q chassis, so a
# quarterly sops-encrypted snapshot additionally lands in the Samba share
# root for the desktop to pull onto its own backup pool. The desktop
# imports this file for the pull half only; nothing here assumes the rest
# of the homelab set exists (the server block stays behind cfg.enable).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) defaults;

  cfg = config.modules.system.homelab.vaultwarden;
  hl = config.modules.system.homelab;

  # On dpool so the existing backup pipeline covers the vault with no extra
  # machinery: sanoid snapshots dpool/data (services/* are plain directories
  # in that single dataset, not child datasets) and syncoid replicates it
  # to bpool/backup/data nightly. The module's default /var/lib state dir
  # would land on the ephemeral root or, when persisted, on rpool/eyd/per,
  # which is snapshotted but never replicated.
  dataFolder = "/per/mnt/data/services/vaultwarden";

  # Snapshot drop folder: a sibling of the live data folder, i.e. inside
  # the Samba share root, so the desktop can pull over SMB with the same
  # credentials the samba module hands out.
  drFolder = "${dataFolder}-dr";

  # drFolder relative to the share root, for smbclient's cd.
  drSharePath = "services/vaultwarden-dr";

  publicUrl = "https://${hl.caddyProxy.tailnetDomain}:${toString cfg.httpsPort}";

  # Every age recipient named in .sops.yaml, flattened at evaluation time.
  # Encrypting to the whole fleet keeps DR independent of any single
  # machine: each host decrypts with its host key, the user with the user
  # key, and no key needs to survive the m920q chassis.
  sopsAgeRecipients = lib.concatStringsSep "," (
    builtins.filter (t: lib.hasPrefix "age1" t) (
      lib.splitString " " (builtins.replaceStrings ["\n"] [" "] (builtins.readFile ../../../.sops.yaml))
    )
  );
in {
  options.modules.system.homelab.vaultwarden = {
    enable = lib.mkEnableOption "vaultwarden Bitwarden-compatible password vault server";

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8447;
      description = "Tailscale Serve HTTPS port terminating TLS for vaultwarden";
    };

    dr = {
      enable = lib.mkEnableOption "quarterly DR snapshot generation: a sops-encrypted tarball of the vault data dropped into the Samba share for the desktop to pull";

      pull = {
        enable = lib.mkEnableOption "client-side pull of vaultwarden DR snapshots from the m920q Samba share onto this host";

        directory = lib.mkOption {
          type = lib.types.str;
          default = "/per/mnt/backup/vaultwarden-dr";
          description = "Local destination for pulled snapshots; must sit directly on the backup pool mount, because the pre-write mount check tests its parent";
        };
      };
    };
  };

  config = lib.mkMerge [
    # ---------- server side (m920q) ----------
    (lib.mkIf cfg.enable {
      assertions = [
        {
          # publicUrl and the Serve unit both derive from the Caddy/Tailscale
          # MagicDNS name; without caddyProxy there is no name to certify.
          assertion = hl.caddyProxy.enable;
          message = "modules.system.homelab.vaultwarden requires modules.system.homelab.caddyProxy.enable (tailnetDomain)";
        }
        {
          assertion =
            cfg.httpsPort
            != hl.zellijWeb.httpsPort
            && cfg.httpsPort != hl.opencodeWeb.httpsPort
            && cfg.httpsPort != hl.homepage.httpsPort
            && cfg.httpsPort != hl.monitoring.prometheusHttpsPort;
          message = "modules.system.homelab.vaultwarden.httpsPort must differ from the zellij-web, opencode-web, homepage and Prometheus Tailscale Serve ports";
        }
      ];

      services.vaultwarden = {
        enable = true;
        config = {
          DATA_FOLDER = dataFolder;
          DOMAIN = publicUrl;
          # Loopback IPv4 instead of the module's ::1 default, so the Serve
          # proxy target and the firewall-less listener agree on 127.0.0.1.
          # ROCKET_PORT must be restated: the option's default is a
          # whole-value fallback, not a per-key merge, and without it
          # vaultwarden would fall back to port 80 (unbindable unprivileged).
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
          # Registration closed after the first account was created; new
          # users can only be added by the admin panel.
          SIGNUPS_ALLOWED = false;
        };
        # ADMIN_TOKEN and friends stay out of the world-readable store.
        environmentFile = [config.sops.secrets."vaultwarden/admin-token".path];
      };

      sops.secrets."vaultwarden/admin-token" = {};

      systemd.services.vaultwarden = {
        # Resolve the /per/mnt/data automount before the unit's mount
        # namespace is built: binding an untriggered autofs point would hide
        # the real dataset behind an empty directory.
        unitConfig.RequiresMountsFor = dataFolder;
        # ProtectSystem=strict only exempts StateDirectory; the data folder on
        # dpool needs its own writable exemption.
        serviceConfig.ReadWritePaths = [dataFolder];
      };

      # Created before the first unit start (same pattern as nextcloud and
      # jellyfin); the access triggers the automount, landing the directory on
      # the real dataset rather than on the root filesystem.
      systemd.tmpfiles.rules = [
        "d ${dataFolder} 0700 vaultwarden vaultwarden -"
      ];

      systemd.services.tailscale-serve-vaultwarden = {
        description = "Expose vaultwarden via Tailscale Serve";
        after = [
          "tailscale.service"
          "vaultwarden.service"
        ];
        wants = [
          "tailscale.service"
          "vaultwarden.service"
        ];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 30;
          Restart = "on-failure";
          RestartSec = 30;
          ExecStart = "${pkgs.writeShellScript "tailscale-serve-vaultwarden-setup" ''
            ${pkgs.tailscale}/bin/tailscale serve --bg \
              --https ${toString cfg.httpsPort} \
              http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
          ''}";
        };
        # Fail loudly and retry when tailscaled is not yet connected; re-serve
        # whenever tailscaled comes back up. Same shape as the sibling
        # tailscale-serve-* units.
        upholds = ["tailscale.service"];
        unitConfig.StartLimitBurst = 5;
        unitConfig.StartLimitIntervalSec = 300;
      };
    })

    # ---------- DR generation (m920q) ----------
    (lib.mkIf cfg.dr.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "modules.system.homelab.vaultwarden.dr.enable requires modules.system.homelab.vaultwarden.enable";
        }
        {
          # The drop folder only reaches the desktop through the share.
          assertion = hl.samba.enable;
          message = "modules.system.homelab.vaultwarden.dr.enable requires modules.system.homelab.samba.enable (the drop folder lives in the share root)";
        }
        {
          assertion = sopsAgeRecipients != "";
          message = "no age recipients parsed from .sops.yaml — the DR snapshot would be unencrypted or unencryptable";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${drFolder} 0775 root sambashare -"
        # The same ACL pair samba.nix grants the share root, applied
        # explicitly so the folder does not depend on inheriting the root's
        # default ACL at creation time.
        "a+ ${drFolder} - - - - g:sambashare:rwx,d:g:sambashare:rwx"
      ];

      systemd.services.vaultwarden-dr-generate = {
        description = "Generate the quarterly vaultwarden DR snapshot";
        # Ordering only: a failed vaultwarden must not block DR of the last
        # good database.
        after = ["vaultwarden.service"];
        serviceConfig = {
          Type = "oneshot";
          ProtectSystem = "strict";
          PrivateTmp = true;
          ReadWritePaths = [drFolder];
          ExecStart = lib.getExe (pkgs.writeShellApplication {
            name = "vaultwarden-dr-generate";
            runtimeInputs = with pkgs; [coreutils curl findutils gnutar sops sqlite];
            text = ''
              set -o errtrace

              alert() {
                curl -fsS \
                  -H "Title: vaultwarden DR generation failed" \
                  -H "Tags: warning,rotating_light" \
                  -d "m920q could not produce the quarterly vault DR snapshot: $1" \
                  http://127.0.0.1:2586/homelab-alerts >/dev/null 2>&1 || true
              }
              trap 'alert "$BASH_COMMAND"' ERR

              data=${dataFolder}
              out=${drFolder}
              work=$(mktemp -d)
              trap 'rm -rf "$work"' EXIT
              mkdir -p "$out"

              # Quarterly cadence without a fixed calendar: the newest
              # artifact carries its creation date, and anything younger
              # than 85 days makes this weekly run a no-op.
              newest=$(find "$out" -maxdepth 1 -name 'vaultwarden-dr-*.enc' -printf '%T@ %p\n' \
                | sort -rn | head -n 1 | cut -d' ' -f2-)
              if [ -n "$newest" ]; then
                if [ $(( $(date +%s) - $(stat -c %Y "$newest") )) -lt $((85 * 86400)) ]; then
                  exit 0
                fi
              fi

              stage="$work/stage"
              mkdir -p "$stage"

              # .backup writes a transactionally consistent copy while the
              # service keeps running — no downtime, and no torn file-level
              # image of a live database.
              sqlite3 "$data/db.sqlite3" ".backup '$stage/db.sqlite3'"

              for sub in attachments sends; do
                if [ -d "$data/$sub" ]; then
                  cp -a "$data/$sub" "$stage/$sub"
                else
                  mkdir -p "$stage/$sub"
                fi
              done
              cp -a "$data/rsa_key.pem" "$stage/rsa_key.pem"

              cat > "$stage/MANIFEST.txt" <<MANIFEST
              vaultwarden DR snapshot
              generated (UTC): $(date -u +%FT%TZ)
              vaultwarden version: ${config.services.vaultwarden.package.version}

              contents: db.sqlite3 (consistent sqlite backup), attachments/,
              sends/, rsa_key.pem

              restore on a fresh host:
                1. sops -d --input-type binary --output-type binary FILE.enc | tar -xz -C /staging
                2. systemctl stop vaultwarden
                3. replace the contents of ${dataFolder} with the extracted files
                4. chown -R vaultwarden:vaultwarden ${dataFolder} && chmod 700 ${dataFolder}
                5. systemctl start vaultwarden
              MANIFEST

              tar -czf "$work/snapshot.tar.gz" -C "$stage" .

              name="vaultwarden-dr-$(date +%F).enc"
              # sops binary mode; recipients come from .sops.yaml at
              # evaluation time (fleet-wide), so decryption never depends
              # on m920q's key surviving.
              sops --encrypt --input-type binary --output-type binary \
                --age '${sopsAgeRecipients}' \
                "$work/snapshot.tar.gz" > "$out/.$name.tmp"
              mv "$out/.$name.tmp" "$out/$name"
              (cd "$out" && sha256sum "$name" > "$name.sha256")

              # Four quarters on disk; oldest first out.
              find "$out" -maxdepth 1 -name 'vaultwarden-dr-*.enc' -printf '%T@ %p\n' \
                | sort -rn | tail -n +5 | while IFS= read -r line; do
                  old=''${line#* }
                  rm -f "$old" "$old.sha256"
                done
            '';
          });
        };
      };

      systemd.timers.vaultwarden-dr-generate = {
        wantedBy = ["timers.target"];
        timerConfig = {
          # Weekly pickup with a due-date check inside the script instead of
          # a quarterly OnCalendar: a missed quarter (failure, maintenance)
          # self-heals on the next weekly run instead of waiting three
          # months for the next calendar slot.
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })

    # ---------- DR pull (desktop) ----------
    (lib.mkIf cfg.dr.pull.enable {
      # The same Samba credential the m920q side uses, materialized for
      # root only; desktop already decrypts secrets.yaml for rbw.
      sops.secrets."samba/user-password" = {};

      # Exists before the unit starts (ProtectSystem ReadWritePaths needs
      # a real path) and lands on the backup pool once it is imported —
      # tmpfiles runs after local-fs.target, by which point ZFS has mounted
      # it when present.
      systemd.tmpfiles.rules = [
        "d ${cfg.dr.pull.directory} 0755 root root -"
      ];

      systemd.services.vaultwarden-dr-pull = {
        description = "Pull the latest vaultwarden DR snapshot from m920q";
        wants = ["network-online.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ProtectSystem = "strict";
          PrivateTmp = true;
          ReadWritePaths = [cfg.dr.pull.directory];
          ExecStart = lib.getExe (pkgs.writeShellApplication {
            name = "vaultwarden-dr-pull";
            runtimeInputs = with pkgs; [coreutils curl findutils gnugrep samba util-linux];
            text = ''
              set -o errtrace

              alert() {
                curl -fsS \
                  -H "Title: vaultwarden DR pull failed" \
                  -H "Tags: warning,rotating_light" \
                  -d "desktop could not fetch the vault DR snapshot: $1" \
                  http://m920q:2586/homelab-alerts >/dev/null 2>&1 || true
              }
              trap 'alert "$BASH_COMMAND"' ERR

              share="//m920q/data"
              dest=${cfg.dr.pull.directory}
              remote=${drSharePath}

              auth=$(mktemp)
              trap 'rm -f "$auth"' EXIT
              umask 077
              printf 'username=%s\npassword=%s\n' '${defaults.system.user}' \
                "$(cat ${config.sops.secrets."samba/user-password".path})" > "$auth"

              # The timer fires shortly after boot (Persistent=true), often
              # before tailscaled publishes MagicDNS — and without it
              # "m920q" does not resolve. Retry for a few minutes and alert
              # only once the window is exhausted, so a single weekly run
              # does not have to wait for the next week.
              smb_retry() {
                local out="" try
                for try in 1 2 3 4 5; do
                  if out=$(smbclient "$share" -A "$auth" -c "$1"); then
                    printf '%s\n' "$out"
                    return 0
                  fi
                  [ "$try" -eq 5 ] || sleep 45
                done
                return 1
              }

              if ! listing=$(smb_retry "cd $remote; ls"); then
                alert "could not list $share/$remote after 5 attempts (tailnet/DNS down?)"
                exit 1
              fi

              missing=()
              while IFS= read -r n; do
                if [ ! -f "$dest/$n" ]; then
                  missing+=("$n")
                fi
              done < <(grep -oE 'vaultwarden-dr-[0-9]{4}-[0-9]{2}-[0-9]{2}\.enc' <<< "$listing" | sort -u || true)
              if [ ''${#missing[@]} -eq 0 ]; then
                exit 0
              fi

              # Something is due. Refuse to write anywhere but the backup
              # pool: while the pool is unplugged the directory sits on a
              # placeholder path that looks writable but is not durable.
              if ! mountpoint -q "$(dirname "$dest")"; then
                alert "DR is due but $(dirname "$dest") is not mounted (backup pool unplugged?)"
                exit 1
              fi
              mkdir -p "$dest"

              for n in "''${missing[@]}"; do
                if ! smb_retry "lcd $dest; cd $remote; get $n; get $n.sha256"; then
                  rm -f "$dest/$n" "$dest/$n.sha256"
                  alert "transfer failed for $n after 5 attempts"
                  exit 1
                fi
                if ! (cd "$dest" && sha256sum -c "$n.sha256" >/dev/null); then
                  rm -f "$dest/$n" "$dest/$n.sha256"
                  alert "checksum mismatch for $n — deleted, the next run retries"
                  exit 1
                fi
              done

              # Four newest snapshots stay local.
              find "$dest" -maxdepth 1 -name 'vaultwarden-dr-*.enc' -printf '%T@ %p\n' \
                | sort -rn | tail -n +5 | while IFS= read -r line; do
                  old=''${line#* }
                  rm -f "$old" "$old.sha256"
                done
            '';
          });
        };
      };

      systemd.timers.vaultwarden-dr-pull = {
        wantedBy = ["timers.target"];
        timerConfig = {
          # Persistent makes a missed run fire at the next boot, which is
          # what "whenever the machine is on" means for an irregularly
          # powered desktop: the pull happens on the first boot after the
          # snapshot becomes due.
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
    })
  ];
}
