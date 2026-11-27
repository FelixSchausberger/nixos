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
  vhosts = config.services.caddy.virtualHosts;
  domain = "schausberger.dev";
  routesTo = host: port:
    builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString port}.*"
    vhosts.${host}.extraConfig
    != null;
  usesWildcardCert = host: vhosts.${host}.useACMEHost == domain;
  hosts = [
    "photos.${domain}"
    "music.${domain}"
    "grafana.${domain}"
    "adguard.${domain}"
    "cloud.${domain}"
    "books.${domain}"
    "home.${domain}"
  ];
in {
  caddy_config_has_immich_port = routesTo "photos.${domain}" ports.immich;
  caddy_config_has_navidrome_port = routesTo "music.${domain}" ports.navidrome;
  caddy_config_has_adguard_port = routesTo "adguard.${domain}" ports.adguard;
  caddy_config_has_nextcloud_port = routesTo "cloud.${domain}" ports.nextcloud;
  caddy_config_has_calibre_port = routesTo "books.${domain}" ports.calibreWeb;
  caddy_config_has_homepage_port = routesTo "home.${domain}" ports.homepage;
  # The apex wildcard certificate is the only certificate source for the
  # public layout; a vhost that fell back to Caddy's own ACME would silently
  # require port 80 reachability and a public A record.
  caddy_vhosts_use_wildcard_cert = builtins.all usesWildcardCert hosts;
}
