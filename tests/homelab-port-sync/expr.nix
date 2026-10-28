# Test: the canonical homelab ports reach the reverse proxy through the module
# options.
#
# lib/homelab-ports.nix is the default source for both the service modules and
# the VM test stubs, so comparing the evaluated defaults against it would only
# restate the definition. What is worth pinning is that caddy-proxy consumes
# the module options instead of carrying its own copies of the numbers: a route
# built from a hardcoded port would stop matching here.
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
  ports = flake.lib.homelabPorts;
  vhost = config.services.caddy.virtualHosts."m920q.tailf2f0ca.ts.net".extraConfig;
  routesTo = port:
    builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString port}.*" vhost != null;
in {
  caddy_config_has_immich_port = routesTo ports.immich;
  caddy_config_has_navidrome_port = routesTo ports.navidrome;
  caddy_config_has_adguard_port = routesTo ports.adguard;
  caddy_config_has_nextcloud_port = routesTo ports.nextcloud;
  caddy_config_has_calibre_port = routesTo ports.calibreWeb;
}
