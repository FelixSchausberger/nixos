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

  # Rendered dashboard card inventory: path, icon, href, and the presence
  # (never the credentials) of per-card probes and widgets. Nested groups
  # (Rescue/AMT, Monitoring/Dashboards) are walked recursively so a card inside
  # a subgroup stays visible in the snapshot diff. The snapshot deliberately
  # records current state rather than asserting reachability, which the site
  # monitors cover at runtime.
  renderCards = prefix: entries:
    builtins.concatLists (map (
        entry: let
          name = builtins.head (builtins.attrNames entry);
          spec = entry.${name};
          path =
            if prefix == ""
            then name
            else "${prefix}/${name}";
        in
          if builtins.isList spec
          then renderCards path spec
          else [
            (path
              + (
                if spec ? icon
                then " icon=${spec.icon}"
                else ""
              )
              + (
                if spec ? href
                then " href=${spec.href}"
                else ""
              )
              + (
                if spec ? siteMonitor
                then " monitor"
                else ""
              )
              + (
                if spec ? widget
                then " widget=${spec.widget.type}"
                else ""
              )
              + (
                if spec ? widgets
                then " widgets=${builtins.concatStringsSep "," (map (w: w.type) spec.widgets)}"
                else ""
              ))
          ]
      )
      entries);
in {
  adguard_enabled = config.modules.system.homelab.adguardhome.enable;
  monitoring_enabled = config.modules.system.homelab.monitoring.enable;
  tailscale_enabled = config.modules.system.homelab.tailscale.enable;
  zellij_web_enabled = config.modules.system.homelab.zellijWeb.enable;
  zellij_web_port = config.modules.system.homelab.zellijWeb.port;
  zellij_web_https_port = config.modules.system.homelab.zellijWeb.httpsPort;
  zellij_web_tailnet_domain = config.modules.system.homelab.zellijWeb.tailnetDomain;
  zellij_web_linger = config.users.users.schausberger.linger;

  smart_home_enabled = config.modules.system.homelab.smartHome.enable;
  # Until the SLZB-MR4U has a reserved LAN address, zigbee2mqtt stays disabled
  # while the broker and Home Assistant already run.
  smart_home_zigbee_enabled = config.services.zigbee2mqtt.enable;
  smart_home_coordinator_url = config.modules.system.homelab.smartHome.coordinatorUrl;
  smart_home_ha_port = config.modules.system.homelab.smartHome.port;
  smart_home_z2m_frontend_port = config.modules.system.homelab.smartHome.frontendPort;
  smart_home_lan_clients = config.modules.system.homelab.smartHome.lanClients;
  smart_home_ha_bind = config.services.home-assistant.config.http.server_host;
  smart_home_mosquitto = let
    l = builtins.head config.services.mosquitto.listeners;
  in {
    only_listener = builtins.length config.services.mosquitto.listeners == 1;
    inherit (l) address omitPasswordAuth acl;
  };
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
  # Home Manager renders one systemd ExecStart= line per list element, and
  # systemd rejects a Type=simple unit with more than one. The command must
  # therefore stay a single element.
  opencode_server_single_exec_start =
    builtins.length config.home-manager.users.schausberger.systemd.user.services.opencode-web.Service.ExecStart == 1;
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

  homepage_cards = renderCards "" config.services.homepage-dashboard.services;
}
