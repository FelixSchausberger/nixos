# Homelab service modules for the m920q server.
# Each sub-module is opt-in via options.modules.system.homelab.<service>.enable.
# Tailscale and backup are top-level modules (shared across hosts).
{
  imports = [
    ./adguardhome.nix
    ./caddy-proxy.nix
    ./homepage.nix
    ./immich.nix
    ./monitoring.nix
    ./navidrome.nix
    ./nextcloud.nix
    ./ntfy.nix
    ./opencode-web.nix
    ./samba.nix
    ./ssh-hardened.nix
    ./zellij-web.nix
  ];
}
