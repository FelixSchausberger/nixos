# Homelab service modules for the m920q server.
# Each sub-module is opt-in via options.modules.system.homelab.<service>.enable.
{
  imports = [
    ./adguardhome.nix
    ./backup.nix
    ./tailscale.nix
    ./immich.nix
    ./nextcloud.nix
    ./monitoring.nix
    ./ssh-hardened.nix
  ];
}
