# Test: homelab port defaults match the canonical lib/homelab-ports.nix
#
# Catches port drift between the VM test stubs (tests-vm/caddy-proxy.nix)
# and the actual module defaults. If a homelab module changes its default
# port, this test and the caddy-proxy test both reference homelabPorts
# so they stay in sync automatically.
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
  ports = flake.lib.homelabPorts;
in {
  # Each attribute verifies the evaluated module default matches the canonical value.
  immich_port = config.modules.system.homelab.immich.port == ports.immich;
  navidrome_port = config.modules.system.homelab.navidrome.port == ports.navidrome;
  grafana_port = config.modules.system.homelab.monitoring.grafanaPort == ports.grafana;
  adguard_port = config.modules.system.homelab.adguardhome.port == ports.adguard;
  nextcloud_port = config.modules.system.homelab.nextcloud.port == ports.nextcloud;
  homepage_port = config.modules.system.homelab.homepage.port == ports.homepage;

  # Verify caddy-proxy actually reads the correct port values into its config.
  # The extraConfig string contains reverse_proxy directives with the port numbers.
  caddy_config_has_immich_port = builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString ports.immich}.*" config.services.caddy.virtualHosts."m920q.tailf2f0ca.ts.net".extraConfig != null;
  caddy_config_has_navidrome_port = builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString ports.navidrome}.*" config.services.caddy.virtualHosts."m920q.tailf2f0ca.ts.net".extraConfig != null;
  caddy_config_has_adguard_port = builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString ports.adguard}.*" config.services.caddy.virtualHosts."m920q.tailf2f0ca.ts.net".extraConfig != null;
  caddy_config_has_nextcloud_port = builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString ports.nextcloud}.*" config.services.caddy.virtualHosts."m920q.tailf2f0ca.ts.net".extraConfig != null;
}
