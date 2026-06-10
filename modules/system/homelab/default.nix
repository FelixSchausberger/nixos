# Homelab service modules for the m920q server.
# Each sub-module is opt-in via options.modules.system.homelab.<service>.enable.
{
  imports = [
    ./adguardhome.nix
    ./backup.nix
    ./immich.nix
    ./monitoring.nix
    ./nextcloud.nix
    ./ntfy.nix
    ./remote-control.nix
    ./samba.nix
    ./tailscale.nix
  ];
}
