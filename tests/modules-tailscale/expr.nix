# Test: Tailscale module produces expected configuration across all hosts
{flake, ...}: let
  configs = flake.nixosConfigurations;

  # Common tailscale assertions for a host config
  testTailscale = hostName: config: {
    inherit hostName;

    # Module is enabled
    tailscale_enabled = config.modules.system.homelab.tailscale.enable;

    # Tailscale service is enabled
    tailscale_service_enabled = config.services.tailscale.enable;

    # Firewall allows tailscale traffic
    has_tailscale_trusted_interface = builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;

    # Firewall is open for tailscale
    tailscale_open_firewall = config.services.tailscale.openFirewall;
  };
in {
  # Primary tailscale hosts
  desktop =
    (testTailscale "desktop" configs.desktop.config)
    // {
      # Desktop has UDP GRO fix on eno1
      udp_gro_interface = configs.desktop.config.modules.system.homelab.tailscale.udpGROInterface;
      has_udp_gro_service = builtins.hasAttr "tailscale-udp-gro-fix" configs.desktop.config.systemd.services;
    };
  hp-probook-wsl = testTailscale "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q =
    (testTailscale "m920q" configs.m920q.config)
    // {
      # Peer connectivity monitor: probes the phone and logs transitions.
      has_peer_monitor_service =
        builtins.hasAttr "tailscale-peer-monitor" configs.m920q.config.systemd.services;
      has_peer_monitor_timer =
        builtins.hasAttr "tailscale-peer-monitor" configs.m920q.config.systemd.timers;
      peer_monitor_peer = configs.m920q.config.modules.system.homelab.tailscale.peerMonitor.peer;
      # Deliverability watch: probe pairs peer reachability with the ntfy
      # subscriber gauge so a wedged phone cannot pass as healthy.
      peer_monitor_subscriber_metrics =
        configs.m920q.config.modules.system.homelab.tailscale.peerMonitor.subscriberMetricsUrl;
      peer_monitor_fallback =
        configs.m920q.config.modules.system.homelab.tailscale.peerMonitor.alertNtfyFallbackUrl;
    };
}
