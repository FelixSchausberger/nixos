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
  surface = flake.nixosConfigurations.surface;
  lib = m920q.pkgs.lib;

  ml = m920q.config.modules.system.homelab.logging;
  dl = desktop.config.modules.system.homelab.logging;
  sl = surface.config.modules.system.homelab.logging;

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
  # The SLZB syslog receiver exists on the aggregator only; shipping hosts
  # must not open an unauthenticated UDP listener.
  assert ml.syslogSource == "192.168.178.74";
  assert ml.syslogPort == 1514;
  assert lib.hasInfix "loki.source.syslog \"slzb\"" m920q.config.environment.etc."alloy/config.alloy".text;
  assert !(lib.hasInfix "loki.source.syslog" desktop.config.environment.etc."alloy/config.alloy".text);
  # The desktop ships to the aggregator and runs no store of its own.
  assert dl.shipEndpoint == "http://m920q:3100";
  assert !desktop.config.services.loki.enable;
  assert desktop.config.services.alloy.enable;
  # The surface is the other roaming client: it ships over the tailnet, where
  # the short name could be answered by a LAN resolver outside clientSources.
  assert sl.shipEndpoint == "http://m920q.tailf2f0ca.ts.net:3100";
  assert !surface.config.services.loki.enable;
  assert surface.config.services.alloy.enable;
  # Alloy must not be a DynamicUser: its state directory would land under
  # /var/lib/private, which the persistence tree cannot provide at the 0700
  # systemd demands.
  assert !m920q.config.systemd.services.alloy.serviceConfig.DynamicUser;
  assert m920q.config.systemd.services.alloy.serviceConfig.User == "alloy";
  assert m920q.config.users.users.alloy.isSystemUser;
  # Loki's own query log would be shipped back into itself by Alloy, so query
  # text would resurface as log content and match later searches.
  assert m920q.config.services.loki.configuration.server.log_level == "warn";
  # The tool that reads the journal must also lift user-unit names and
  # normalise severity; both are load-bearing for the error views.
  assert lib.hasInfix "loki.process \"levels\"" m920q.config.environment.etc."alloy/config.alloy".text;
  assert lib.hasInfix "user_unit" m920q.config.environment.etc."alloy/config.alloy".text;
  # The syslog receiver needs the host label to be visible to fleet queries.
  assert lib.hasInfix "host = \"m920q\"" m920q.config.environment.etc."alloy/config.alloy".text;
  # The error view filters on level, so app formats must lift their severity.
  assert lib.hasInfix "app_level>ERR" m920q.config.environment.etc."alloy/config.alloy".text;
  assert lib.hasInfix "app_level>ERROR|WARNING|CRITICAL" m920q.config.environment.etc."alloy/config.alloy".text; {
    loki_enabled = m920q.config.services.loki.enable;
    loki_port = ml.lokiPort;
    loki_log_level = m920q.config.services.loki.configuration.server.log_level;
    loki_http_listen_address =
      m920q.config.services.loki.configuration.server.http_listen_address;
    loki_retention = m920q.config.services.loki.configuration.limits_config.retention_period;
    loki_client_sources = ml.clientSources;
    syslog_port = ml.syslogPort;
    syslog_source = ml.syslogSource;
    firewall_extra_input_rules = m920q.config.networking.firewall.extraInputRules;
    grafana_datasources = map (d: d.uid) datasources;
    logs_dashboard_provisioned = builtins.any (p: p.name == "logs") providers;
    alloy_aggregator_enabled = m920q.config.services.alloy.enable;
    alloy_aggregator_config = m920q.config.environment.etc."alloy/config.alloy".text;
    desktop_loki_enabled = desktop.config.services.loki.enable;
    desktop_alloy_enabled = desktop.config.services.alloy.enable;
    desktop_ship_endpoint = dl.shipEndpoint;
    surface_loki_enabled = surface.config.services.loki.enable;
    surface_alloy_enabled = surface.config.services.alloy.enable;
    surface_ship_endpoint = sl.shipEndpoint;
  }
