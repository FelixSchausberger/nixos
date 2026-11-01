# Collie (https://colliepwa.dev) - the phone-facing bridge for the herd's
# agent panes. The bridge mirrors herdr panes over the tailnet and turns
# permission prompts and questions into tappable approval cards, replacing
# the read-only zellij-web transport for agent work (zellij-web stays for
# the manual session).
#
# Architecture:
#   - `collie _exec-bridge` runs as a systemd system service under the
#     primary user (zellij-web pattern) so it can read the user's herdr
#     socket at any time of day. The verb is what upstream's own generated
#     service unit launches; `collie start`/`stop` also manage their own
#     user unit and are deliberately not used here - manage the bridge
#     with systemctl, never `collie start`.
#   - The binary is upstream's flake package (flake input collie): their
#     derivation wraps the manifest-hashed release payload and lays out the
#     Bun-root tree the bundle expects (bin/collie as a symlink into
#     lib/collie with herdr-plugin.toml at the root it resolves by realpath).
#     A bare copy of bin/collie on PATH is the exact failure class the first
#     attempt hit: root resolution fails, the CLI falls into bun-run
#     fallback, and every verb prints "Script not found". `collie update`
#     refuses a store install ("packaged" classification), so version
#     bumps ride the flake lock only.
#   - Collie binds 127.0.0.1 and owns no front door: COLLIE_SKIP_SERVE=1
#     keeps it from running `tailscale serve` itself (which would need
#     operator rights and would fight the declarative serve units). A
#     tailscale-serve oneshot terminates TLS on a dedicated HTTPS port,
#     same as zellij-web/opencode-web.
#   - Host validation fails closed: without COLLIE_PUBLIC_HOSTS and
#     COLLIE_ALLOWED_ORIGINS the phone would load an empty page.
#   - The user CLI (pair, qr, doctor) reads ~/.config/collie/.env, rendered
#     by the home TUI collie module from these same options; the service
#     takes its values directly as unit Environment entries.
#   - Web Push (requires VAPID keys in the env) is not configured yet:
#     `collie push-keys` writes into the user's .env, which is an HM
#     store symlink, so keys arrive via a sops template when push is
#     wanted; until then the phone dashboard polls without push.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.collie;

  tailscaleServe = import ../../../lib/tailscale-serve.nix {inherit pkgs;};

  user = inputs.self.lib.user;
  homeDir = "/home/${user}";
  uid = 1000; # must match users.nix
in {
  options.modules.system.homelab.collie = {
    enable = lib.mkEnableOption "Collie phone bridge for herdr";

    bridgePort = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Loopback port the Collie bridge binds (upstream default)";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8455;
      description = "Tailscale Serve HTTPS port terminating TLS for the Collie bridge";
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      example = "m920q.tailf2f0ca.ts.net";
      description = "MagicDNS hostname for this node (host.tailnet.ts.net)";
    };

    trustedUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "user@example.com";
      description = ''
        Tailscale login (*@example.com) allowed to drive the agents. Null
        leaves the driver gate to the paired-device list only, which the
        bridge flags with a TRUSTED_USER warning on a shared tailnet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetDomain != "";
        message = "modules.system.homelab.collie.tailnetDomain must be set (e.g. 'm920q.tailf2f0ca.ts.net')";
      }
      {
        assertion =
          cfg.httpsPort
          != config.modules.system.homelab.zellijWeb.httpsPort
          && cfg.httpsPort != config.modules.system.homelab.opencodeWeb.httpsPort
          && cfg.httpsPort != config.modules.system.homelab.homepage.httpsPort
          && cfg.httpsPort != config.modules.system.homelab.smartHome.httpsPort
          && cfg.httpsPort != config.modules.system.homelab.monitoring.prometheusHttpsPort;
        message = "modules.system.homelab.collie.httpsPort must differ from the zellij-web, opencode-web, homepage, smart-home and Prometheus Tailscale Serve ports";
      }
    ];

    # Keeps the primary user's user manager alive so /run/user/1000 exists
    # and pairing state in ~/.local/state/collie survives logout; shared
    # with the zellij-web module's linger declaration.
    users.users.${user}.linger = true;

    systemd.services.collie = {
      description = "Collie bridge for herdr (phone agent control)";
      after = [
        "network.target"
        "tailscaled.service"
        "user@${toString uid}.service"
      ];
      wants = [
        "tailscaled.service"
        "user@${toString uid}.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = user;
        Group = "users";
        Type = "simple";
        Restart = "always";
        RestartSec = "5";
        ExecStart = "${pkgs.collie}/bin/collie _exec-bridge";
        Environment =
          [
            "HOME=${homeDir}"
            # Login-equivalent PATH for harness discovery (collie doctor's
            # harness table) and anything Collie starts itself.
            "PATH=${homeDir}/.local/bin:/run/wrappers/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
            "XDG_DATA_HOME=${homeDir}/.local/share"
            "XDG_CACHE_HOME=${homeDir}/.cache"
            "XDG_RUNTIME_DIR=/run/user/${toString uid}"
            "COLLIE_PORT=${toString cfg.bridgePort}"
            "COLLIE_HOST=127.0.0.1"
            "COLLIE_MUX=herdr"
            # The tailscale-serve oneshot owns the front door.
            "COLLIE_SKIP_SERVE=1"
            "COLLIE_PUBLIC_HOSTS=${cfg.tailnetDomain},${cfg.tailnetDomain}:${toString cfg.httpsPort}"
            "COLLIE_ALLOWED_ORIGINS=https://${cfg.tailnetDomain}:${toString cfg.httpsPort}"
            "COLLIE_PUBLIC_URL=https://${cfg.tailnetDomain}:${toString cfg.httpsPort}"
          ]
          ++ lib.optionals (cfg.trustedUser != null) [
            "COLLIE_TRUSTED_USER=${cfg.trustedUser}"
          ];
      };
    };

    systemd.services.tailscale-serve-collie = tailscaleServe {
      name = "tailscale-serve-collie";
      description = "Expose Collie bridge via Tailscale Serve";
      inherit (cfg) httpsPort;
      upstreamPort = cfg.bridgePort;
      after = ["collie.service"];
      wants = ["collie.service"];
    };
  };
}
