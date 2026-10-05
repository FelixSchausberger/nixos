# Self-hosted Bitwarden-compatible server for the personal vault, consumed
# by rbw in the terminal and the official Bitwarden apps on Android
# (autofill + TOTP). The server itself is tailnet-only: clients reach it
# through a dedicated Tailscale Serve port, the same primitive as
# zellij-web, opencode-web and homepage. A path-routed Caddy prefix is not
# viable — the Bitwarden web vault is a root-served SPA with root-absolute
# asset URLs (the same failure mode documented in homepage.nix), Immich
# already owns the Caddy root catch-all, and Tailscale issues certificates
# only for the exact MagicDNS hostname, never for a subdomain.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.vaultwarden;
  hl = config.modules.system.homelab;

  # On dpool so the existing backup pipeline covers the vault with no extra
  # machinery: sanoid snapshots dpool/data (services/* are plain directories
  # in that single dataset, not child datasets) and syncoid replicates it
  # to bpool/backup/data nightly. The module's default /var/lib state dir
  # would land on the ephemeral root or, when persisted, on rpool/eyd/per,
  # which is snapshotted but never replicated.
  dataFolder = "/per/mnt/data/services/vaultwarden";

  publicUrl = "https://${hl.caddyProxy.tailnetDomain}:${toString cfg.httpsPort}";
in {
  options.modules.system.homelab.vaultwarden = {
    enable = lib.mkEnableOption "vaultwarden Bitwarden-compatible password vault server";

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8447;
      description = "Tailscale Serve HTTPS port terminating TLS for vaultwarden";
    };
  };

  config = lib.mkIf cfg.enable {
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
  };
}
