# Remote attach helper for the homelab Zellij web server on m920q.
# The server side is modules/system/homelab/zellij-web.nix (systemd service +
# Tailscale Serve on port 8443). Clients attach with the documented URL format
# `zellij attach https://<host>:<port>/<session>`; the path is the session name.
#
# The web auth token is created once on the server (`zellij web --create-token`)
# and stored here via sops. `-r` remembers auth on the client for 4 weeks, but
# reading the token fresh each run keeps rotation in a single place (sops).
{config, ...}: let
  host = "m920q.tailf2f0ca.ts.net";
  httpsPort = "8443";
  session = "homelab";
  tokenFile = config.sops.secrets."zellij-token".path;
in {
  sops.secrets."zellij-token" = {};

  programs.fish.functions.zr = {
    description = "Attach to the homelab Zellij session over HTTPS (auto-reconnects on drops)";
    body = ''
      set -l token (string trim < "${tokenFile}" 2>/dev/null)
      if test -z "$token"
        echo "zr: zellij token not available (add 'zellij-token' to secrets/secrets.yaml)" >&2
        return 1
      end

      # Never run two nested zellij sessions (user invariant). If already inside
      # any zellij session, attaching again would nest, so:
      # - inside the homelab session: already at the desired outer session -> no-op success.
      # - inside a different session: refuse and tell the user to detach first.
      if set -q ZELLIJ_SESSION_NAME
        if string match -q "${session}" "$ZELLIJ_SESSION_NAME"
          echo "zr: already attached to session '${session}' -- nothing to do" >&2
          return 0
        else
          echo "zr: inside zellij session '$ZELLIJ_SESSION_NAME'; detach first (Ctrl-g d), then run zr to attach to '${session}'" >&2
          return 1
        end
      end

      while true
        zellij attach "https://${host}:${httpsPort}/${session}" -t "$token" -r
        set -l code $status
        if test $code -eq 0
          return 0
        end
        echo "zr: connection to ${host} lost (exit $code), reconnecting in 2s (Ctrl-C to quit)" >&2
        sleep 2
      end
    '';
  };
}
