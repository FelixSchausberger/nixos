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
  portable = testTailscale "portable" configs.portable.config;
  surface = testTailscale "surface" configs.surface.config;
  hp-probook-vmware = testTailscale "hp-probook-vmware" configs.hp-probook-vmware.config;
  hp-probook-wsl = testTailscale "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testTailscale "m920q" configs.m920q.config;
}
