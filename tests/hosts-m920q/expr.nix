# Test: m920q host configuration builds correctly
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: GUI stack is present but the session starts on demand
  is_gui = config.hostConfig.isGui;
  auto_start_session = config.hostConfig.autoStartSession;
  session_on_demand_enabled = config.modules.system.sessionOnDemand.enable;
  wm_count = builtins.length config.hostConfig.wms;

  # Test: Performance profile set to server-efficiency
  performance_profile = config.hostConfig.performanceProfile;

  # Test: NetworkManager disabled, networkd enabled
  networkmanager_disabled = !config.networking.networkmanager.enable;
  networkd_enabled = config.networking.useNetworkd;

  # Test: Static IP configured on eno1
  has_static_address = builtins.elem "192.168.178.2/24" (config.systemd.network.networks."10-eno1".address or []);
  has_gateway = builtins.elem "192.168.178.1" (config.systemd.network.networks."10-eno1".gateway or []);

  # Test: Homelab modules enabled
  containers_enabled = config.modules.system.containers.enable;

  # Test: Key homelab services enabled
  adguardhome_enabled = config.modules.system.homelab.adguardhome.enable;
  immich_enabled = config.modules.system.homelab.immich.enable;
  jellyfin_enabled = config.modules.system.homelab.jellyfin.enable;
  navidrome_enabled = config.modules.system.homelab.navidrome.enable;
  nextcloud_enabled = config.modules.system.homelab.nextcloud.enable;
  caddy_proxy_enabled = config.modules.system.homelab.caddyProxy.enable;
  homepage_enabled = config.modules.system.homelab.homepage.enable;
  ntfy_enabled = config.modules.system.homelab.ntfy.enable;
  # Subscriber gauge on the main listener: feeds the tailscale peer monitor's
  # deliverability check (tunnel up is not the same as messages delivered).
  ntfy_metrics_enabled = config.services.ntfy-sh.settings.enable-metrics or false;
  samba_enabled = config.modules.system.homelab.samba.enable;
  ssh_enabled = config.modules.system.homelab.ssh.enable;
  pq_kex_enabled = builtins.elem "mlkem768x25519-sha256" config.services.openssh.settings.KexAlgorithms;
  zellij_web_enabled = config.modules.system.homelab.zellijWeb.enable;
  opencode_web_enabled = config.modules.system.homelab.opencodeWeb.enable;
  tailscale_openssh_enabled = config.modules.system.homelab.tailscale.openSSH;

  # Test: Tailscale configured with route advertising
  tailscale_enabled = config.modules.system.homelab.tailscale.enable;
  tailscale_routes = config.modules.system.homelab.tailscale.advertiseRoutes;
  has_192_168_178_route = builtins.elem "192.168.178.0/24" config.modules.system.homelab.tailscale.advertiseRoutes;

  # Test: Maintenance with deferred restarts
  maintenance_enabled = config.modules.system.maintenance.enable;
  deferred_restarts_enabled = config.modules.system.maintenance.deferredRestarts.enable;
  has_deferred_services = config.modules.system.maintenance.deferredRestarts.services != [];

  # Test: Power management profile
  power_management_enabled = config.hardware.profiles.powerManagement.enable;
  power_lan_interface = config.hardware.profiles.powerManagement.lanInterface;

  # Test: Smartd monitoring
  smartd_enabled = config.services.smartd.enable;
  # Test: Quiet hours (00:00-09:00 bedroom window). smartd slots have the
  # (S|L)/../.././HH shape; guard that no slot starts inside the window.
  smartd_schedule = config.services.smartd.defaults.autodetected;
  smartd_schedule_quiet_safe =
    builtins.match
    ".*(S/../../\\./0[0-8]|L/../../\\./0[0-8]).*"
    config.services.smartd.defaults.autodetected
    == null;
  # Test: nightly determinate-nixd GC cadence exposes a metric to Grafana so
  # the automatic-vs-scheduled strategy can be decided from data.
  nixd_gc_metric =
    builtins.elem "--collector.textfile.directory=/var/lib/node-exporter/textfile"
    config.services.prometheus.exporters.node.extraFlags;

  # Test: Backup configured
  backup_enabled = config.modules.system.homelab.backup.enable;

  # Test: desktop-power helper is packaged and the HTTP power-relay is gone
  desktop_power_helper =
    builtins.any (
      p: (p.pname or "") == "desktop-power" || (p.name or "") == "desktop-power"
    )
    config.environment.systemPackages;
  power_relay_service_absent = !(config.systemd.services ? "power-relay");
  power_relay_option_absent = !(config.modules.system.homelab ? powerRelay);
}
