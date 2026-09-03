# Exposes Zellij's built-in web server (terminal + browser remote sessions) over
# the tailnet.
#
# Architecture:
#   - `zellij web` runs as a systemd system service under the primary user so it
#     can serve sessions that user starts via SSH. It binds to 127.0.0.1 only.
#   - A tailscale serve oneshot terminates TLS on a dedicated HTTPS port and
#     forwards to the local web server.
#   - Clients attach with the documented format
#     `zellij attach https://<host>:<httpsPort>/<session-name>`. The URL path is
#     the session name, so Zellij must be served at root (no path-routed Caddy
#     prefix, which would corrupt session-name parsing).
#   - Tailscale HTTPS certificates are Let's Encrypt-issued, so clients validate
#     them against the standard system trust store without extra CA setup.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.zellijWeb;

  user = inputs.self.lib.user;
  homeDir = "/home/${user}";
  # Matches the primary user UID already hardcoded in the m920q mode-switch script.
  uid = 1000;
  runtimeDir = "/run/user/${toString uid}";

  # Port of the persistent shared opencode server (opencode-web HM user service).
  # The web session seeds an attach pane to it so phone access survives reboots.
  opencodePort = config.modules.system.homelab.opencodeWeb.port;
  # Waits for the shared server, then attaches (avoids an empty pane if the user
  # service is not up yet at seed time). Uses `opencode attach` (not a throwaway
  # `opencode`) so it joins the same session store as the web UI and other clients.
  opencodeSeedCmd = "${pkgs.bash}/bin/sh -c 'until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString opencodePort} >/dev/null 2>&1; do sleep 2; done; exec opencode attach http://127.0.0.1:${toString opencodePort}'";
in {
  options.modules.system.homelab.zellijWeb = {
    enable = lib.mkEnableOption "Zellij web server for remote terminal sessions";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Local port the Zellij web server binds on";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Tailscale Serve HTTPS port terminating TLS for the Zellij web server";
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      example = "m920q.tailf2f0ca.ts.net";
      description = "MagicDNS hostname for this node (host.tailnet.ts.net)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetDomain != "";
        message = "modules.system.homelab.zellijWeb.tailnetDomain must be set (e.g. 'm920q.tailf2f0ca.ts.net')";
      }
    ];

    # Keeps the primary user's user manager alive so /run/user/1000 exists even
    # on this headless host; the web server and SSH-started sessions then share
    # the same XDG_RUNTIME_DIR.
    users.users.${user}.linger = true;

    systemd.services.zellij-web = {
      description = "Zellij web server for remote terminal sessions";
      after = [
        "network.target"
        "tailscale.service"
        "user@${toString uid}.service"
      ];
      wants = [
        "tailscale.service"
        "user@${toString uid}.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = user;
        Group = "users";
        Type = "simple";
        Restart = "always";
        RestartSec = "5";
        ExecStart = pkgs.writeShellScript "zellij-web" ''
          set -u
          # Seed the web session with an opencode attach pane once the server is up.
          # Runs in a subshell so `exec` below stays the service's main process
          # (systemd manages the zellij web server correctly on stop/restart).
          (
            for _ in $(seq 1 30); do
              if ${pkgs.zellij}/bin/zellij list-sessions --no-formatting 2>/dev/null | grep -qx web; then
                break
              fi
              sleep 1
            done
            # Idempotent: skip if a pane already references opencode (e.g. after a
            # service restart that preserved the session).
            if ! ZELLIJ_SESSION_NAME=web ${pkgs.zellij}/bin/zellij action dump-layout 2>/dev/null | grep -q "opencode"; then
              ZELLIJ_SESSION_NAME=web ${pkgs.zellij}/bin/zellij action new-pane -- ${opencodeSeedCmd} 2>/dev/null || true
            fi
          ) &
          exec ${pkgs.zellij}/bin/zellij web --start --ip 127.0.0.1 --port ${toString cfg.port}
        '';
        Environment = [
          "HOME=${homeDir}"
          # Login-equivalent PATH so sessions spawned by the web server can
          # resolve the user shell (fish lives under /etc/profiles/per-user)
          # and standard system tools.
          "PATH=${homeDir}/.local/bin:/run/wrappers/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
          "XDG_DATA_HOME=${homeDir}/.local/share"
          "XDG_CACHE_HOME=${homeDir}/.cache"
          "XDG_RUNTIME_DIR=${runtimeDir}"
        ];
      };
    };

    systemd.services.tailscale-serve-zellij-web = {
      description = "Expose Zellij web server via Tailscale Serve";
      after = [
        "tailscale.service"
        "zellij-web.service"
      ];
      wants = [
        "tailscale.service"
        "zellij-web.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        ExecStart = "${pkgs.writeShellScript "tailscale-serve-zellij-setup" ''
          ${pkgs.tailscale}/bin/tailscale serve --bg \
            --https ${toString cfg.httpsPort} \
            http://127.0.0.1:${toString cfg.port} \
            || echo "Warning: tailscale serve setup failed (non-fatal)"
        ''}";
      };
    };
  };
}
