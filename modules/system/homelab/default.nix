# Homelab service modules for the m920q server.
# Each sub-module is opt-in via options.modules.system.homelab.<service>.enable.
# Tailscale and backup are top-level modules (shared across hosts).
{
  imports = [
    ./adguardhome.nix
    ./calibre-web.nix
    ./caddy-proxy.nix
    ./garmin.nix
    ./homepage.nix
    ./immich.nix
    ./jellyfin.nix
    ./logging.nix
    ./monitoring.nix
    ./music-assistant.nix
    ./navidrome.nix
    ./nextcloud.nix
    ./ntfy.nix
    ./opencode-web.nix
    ./samba.nix
    ./smart-home.nix
    ./ssh-hardened.nix
    ./syncthing-vault.nix
    ./vault-mount.nix
    ./vaultwarden.nix
    ./zellij-web.nix
  ];
}
