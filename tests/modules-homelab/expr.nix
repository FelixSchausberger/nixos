# Test: homelab module assertions and key settings
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;

  hasAssertionWithMessage = message: builtins.any (assertion: (assertion.message or "") == message) config.assertions;

  # Strip the volatile store hash (changes on every lock update) while keeping
  # the derivation name and path tail, so semantic changes stay visible.
  # systemd ExecStart values may be a list or a string; handles both.
  stripStoreHash = v: let
    go = x: let
      m = builtins.match "^/nix/store/[a-z0-9]+-(.*)" (toString x);
    in
      if m != null
      then "/nix/store/<hash>/" + builtins.head m
      else x;
  in
    if builtins.isList v
    then map go v
    else go v;
in {
  adguard_enabled = config.modules.system.homelab.adguardhome.enable;
  monitoring_enabled = config.modules.system.homelab.monitoring.enable;
  tailscale_enabled = config.modules.system.homelab.tailscale.enable;
  zellij_web_enabled = config.modules.system.homelab.zellijWeb.enable;
  zellij_web_port = config.modules.system.homelab.zellijWeb.port;
  zellij_web_https_port = config.modules.system.homelab.zellijWeb.httpsPort;
  zellij_web_tailnet_domain = config.modules.system.homelab.zellijWeb.tailnetDomain;
  zellij_web_linger = config.users.users.schausberger.linger;
  zellij_web_service_exec_start =
    config.systemd.services.zellij-web.serviceConfig.ExecStart;
  zellij_web_home_sharing =
    config.home-manager.users.schausberger.programs.zellij.settings.web_sharing;
  opencode_web_enabled = config.modules.system.homelab.opencodeWeb.enable;
  opencode_web_port = config.modules.system.homelab.opencodeWeb.port;
  opencode_web_https_port = config.modules.system.homelab.opencodeWeb.httpsPort;
  opencode_web_tailnet_domain = config.modules.system.homelab.opencodeWeb.tailnetDomain;
  opencode_web_serve_exec_start =
    stripStoreHash config.systemd.services.tailscale-serve-opencode-web.serviceConfig.ExecStart;
  # HM-level server unit: loopback bind and project-scoped CWD
  opencode_server_exec_start =
    stripStoreHash config.home-manager.users.schausberger.systemd.user.services.opencode-web.Service.ExecStart;
  opencode_server_working_directory =
    config.home-manager.users.schausberger.systemd.user.services.opencode-web.Service.WorkingDirectory;

  has_adguard_port_assertion = hasAssertionWithMessage "AdGuard Home admin UI port must not be 53 (reserved for DNS service)";
  has_adguard_grafana_assertion = hasAssertionWithMessage "AdGuard Home admin UI port must differ from Grafana port when monitoring is enabled";
  has_monitoring_ports_assertion = hasAssertionWithMessage "Grafana and Prometheus must use different ports";
  has_tailscale_interface_assertion = hasAssertionWithMessage "modules.system.homelab.tailscale.udpGROInterface must be null or a non-empty interface name";
  has_opencode_web_https_assertion = hasAssertionWithMessage "modules.system.homelab.opencodeWeb.httpsPort must differ from 8443 (zellij-web uses it)";

  grafana_port = config.modules.system.homelab.monitoring.grafanaPort;
  prometheus_port = config.modules.system.homelab.monitoring.prometheusPort;
  adguard_port = config.modules.system.homelab.adguardhome.port;
}
