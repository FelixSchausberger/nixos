# Canonical port defaults for homelab services.
# Single source of truth: VM tests and namaka drift checks reference these values.
{
  immich = 2283; # modules/system/homelab/immich.nix
  navidrome = 4533; # modules/system/homelab/navidrome.nix
  grafana = 3001; # modules/system/homelab/monitoring.nix
  adguard = 3000; # modules/system/homelab/adguardhome.nix
  nextcloud = 8081; # modules/system/homelab/nextcloud.nix
  homepage = 3002; # modules/system/homelab/homepage.nix
}
