# Test: m920q host configuration builds correctly
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: System is TUI-only (headless homelab server)
  is_gui = config.hostConfig.isGui;
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
  m920q_module_enabled = config.modules.system.m920q.enable;
  containers_enabled = config.modules.system.containers.enable;

  # Test: Key homelab services enabled
  adguardhome_enabled = config.modules.system.homelab.adguardhome.enable;
  immich_enabled = config.modules.system.homelab.immich.enable;
  navidrome_enabled = config.modules.system.homelab.navidrome.enable;
  nextcloud_enabled = config.modules.system.homelab.nextcloud.enable;
  caddy_proxy_enabled = config.modules.system.homelab.caddyProxy.enable;
  homepage_enabled = config.modules.system.homelab.homepage.enable;
  ntfy_enabled = config.modules.system.homelab.ntfy.enable;
  samba_enabled = config.modules.system.homelab.samba.enable;
  ssh_enabled = config.modules.system.homelab.ssh.enable;
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

  # Test: Backup configured
  backup_enabled = config.modules.system.homelab.backup.enable;
}
