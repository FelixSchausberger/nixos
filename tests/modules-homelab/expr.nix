# Test: homelab module assertions and key settings
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;

  hasAssertionWithMessage = message: builtins.any (assertion: (assertion.message or "") == message) config.assertions;
in {
  adguard_enabled = config.modules.system.homelab.adguardhome.enable;
  monitoring_enabled = config.modules.system.homelab.monitoring.enable;
  tailscale_enabled = config.modules.system.homelab.tailscale.enable;

  has_adguard_port_assertion = hasAssertionWithMessage "AdGuard Home admin UI port must not be 53 (reserved for DNS service)";
  has_adguard_grafana_assertion = hasAssertionWithMessage "AdGuard Home admin UI port must differ from Grafana port when monitoring is enabled";
  has_monitoring_ports_assertion = hasAssertionWithMessage "Grafana and Prometheus must use different ports";
  has_tailscale_interface_assertion = hasAssertionWithMessage "modules.system.homelab.tailscale.udpGROInterface must be null or a non-empty interface name";

  grafana_port = config.modules.system.homelab.monitoring.grafanaPort;
  prometheus_port = config.modules.system.homelab.monitoring.prometheusPort;
  adguard_port = config.modules.system.homelab.adguardhome.port;
}
