# Exposes the opencode web UI over the tailnet via Tailscale Serve.
#
# Architecture:
#   - The opencode server itself is the HM-level user service
#     `opencode-web` (programs.opencode.web), bound to 127.0.0.1 only.
#   - This module adds the system-level Tailscale Serve oneshot that
#     terminates TLS and forwards to it, mirroring zellij-web.nix.
#   - Tailscale HTTPS certificates are Let's Encrypt-issued for the exact
#     MagicDNS hostname (subdomains are not certifiable), so the UI lives at
#     https://<host>:<httpsPort>/ with no path prefix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.opencodeWeb;
  hl = config.modules.system.homelab;
in {
  options.modules.system.homelab.opencodeWeb = {
    enable = lib.mkEnableOption "Tailscale Serve exposure for the opencode web UI";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Local opencode server port (must match programs.opencode.web extraArgs)";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8444;
      description = "Tailscale Serve HTTPS port terminating TLS for the opencode web UI";
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
        message = "modules.system.homelab.opencodeWeb.tailnetDomain must be set (e.g. 'm920q.tailf2f0ca.ts.net')";
      }
      {
        assertion = !hl.zellijWeb.enable || cfg.httpsPort != hl.zellijWeb.httpsPort;
        message = "modules.system.homelab.opencodeWeb.httpsPort must differ from ${toString hl.zellijWeb.httpsPort} (zellij-web uses it)";
      }
    ];

    systemd.services.tailscale-serve-opencode-web = {
      description = "Expose opencode web UI via Tailscale Serve";
      after = ["tailscale.service"];
      wants = ["tailscale.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        ExecStart = "${pkgs.writeShellScript "tailscale-serve-opencode-setup" ''
          ${pkgs.tailscale}/bin/tailscale serve --bg \
            --https ${toString cfg.httpsPort} \
            http://127.0.0.1:${toString cfg.port} \
            || echo "Warning: tailscale serve setup failed (non-fatal)"
        ''}";
      };
    };
  };
}
