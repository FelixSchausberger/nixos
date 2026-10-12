# Test: Loki log aggregation wiring.
#
# The aggregator (m920q) runs Loki and ships its own journal through Alloy to
# the loopback listener; the desktop runs no Loki and ships to the m920q push
# endpoint. Loki is unauthenticated, so the LAN path is scoped to the hosts
# listed in clientSources rather than opened fleet-wide. These checks pin the
# parts that would otherwise fail silently (an Alloy config that reads no
# journal, a datasource/dashboard that references a missing Loki, a firewall
# rule scoped to the wrong host); the rendered Alloy config is snapshotted so
# an intentional pipeline change stays reviewable.
{flake, ...}: let
  m920q = flake.nixosConfigurations.m920q;
  desktop = flake.nixosConfigurations.desktop;

  ml = m920q.config.modules.system.homelab.logging;
  dl = desktop.config.modules.system.homelab.logging;

  datasources = m920q.config.services.grafana.provision.datasources.settings.datasources;
  providers = m920q.config.services.grafana.provision.dashboards.settings.providers;
in
  # The aggregator stores logs and provisions the Grafana surface for them.
  assert ml.enable;
  assert m920q.config.services.loki.enable;
  assert ml.lokiPort == 3100;
  assert builtins.any (d: d.uid == "loki") datasources;
  assert builtins.any (p: p.name == "logs") providers;
  # Loki is not opened LAN-wide: exactly the named client sources are allowed.
  assert builtins.elem "192.168.178.3" ml.clientSources;
  # The desktop ships to the aggregator and runs no store of its own.
  assert dl.shipEndpoint == "http://m920q:3100";
  assert !desktop.config.services.loki.enable;
  assert desktop.config.services.alloy.enable;
  # Alloy must not be a DynamicUser: its state directory would land under
  # /var/lib/private, which the persistence tree cannot provide at the 0700
  # systemd demands.
  assert !m920q.config.systemd.services.alloy.serviceConfig.DynamicUser;
  assert m920q.config.systemd.services.alloy.serviceConfig.User == "alloy";
  assert m920q.config.users.users.alloy.isSystemUser; {
    loki_enabled = m920q.config.services.loki.enable;
    loki_port = ml.lokiPort;
    loki_http_listen_address =
      m920q.config.services.loki.configuration.server.http_listen_address;
    loki_retention = m920q.config.services.loki.configuration.limits_config.retention_period;
    loki_client_sources = ml.clientSources;
    firewall_extra_input_rules = m920q.config.networking.firewall.extraInputRules;
    grafana_datasources = map (d: d.uid) datasources;
    logs_dashboard_provisioned = builtins.any (p: p.name == "logs") providers;
    alloy_aggregator_enabled = m920q.config.services.alloy.enable;
    alloy_aggregator_config = m920q.config.environment.etc."alloy/config.alloy".text;
    desktop_loki_enabled = desktop.config.services.loki.enable;
    desktop_alloy_enabled = desktop.config.services.alloy.enable;
    desktop_ship_endpoint = dl.shipEndpoint;
  }
