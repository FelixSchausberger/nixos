# Exposes Zellij's built-in web server (terminal + browser remote sessions) over
# the tailnet.
#
# Architecture:
#   - `zellij web` runs as a systemd system service under the primary user so it
#     can serve sessions that user starts via SSH. It binds to 127.0.0.1 only.
#   - A tailscale serve oneshot terminates TLS on a dedicated HTTPS port and
#     forwards to the local web server, mirroring remote-control.nix.
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
in {
  options.modules.system.homelab.zellijWeb = {
    enable = lib.mkEnableOption "Zellij web server for remote terminal sessions";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Local port the Zellij web server binds on (remote-control uses 8082)";
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
      {
        assertion = cfg.port != 8082;
        message = "modules.system.homelab.zellijWeb.port must differ from 8082 (remote-control uses it)";
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
        ExecStart =
          "${pkgs.zellij}/bin/zellij web --start "
          + "--ip 127.0.0.1 --port ${toString cfg.port}";
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
