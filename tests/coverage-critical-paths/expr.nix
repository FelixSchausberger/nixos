# Test: Critical paths coverage for all hosts
# Ensures boot, networking, users, security, and systemd services are evaluated
{flake, ...}: let
  # Get all NixOS configurations
  configs = flake.nixosConfigurations;

  # Extract critical paths for a host
  getCriticalPaths = hostName: config: {
    inherit hostName;

    # Boot configuration
    boot = {
      loader = config.boot.loader.systemd-boot.enable or config.boot.loader.grub.enable or false;
      kernel_is_linux = builtins.match "linux.*" (config.boot.kernelPackages.kernel.name or "") != null;
      has_ext4_module = builtins.elem "ext4" (config.boot.initrd.availableKernelModules or []);
      has_nfs_module = builtins.elem "nfs" (config.boot.initrd.availableKernelModules or []);
      has_usb_storage = builtins.elem "usb_storage" (config.boot.kernelModules or []);
    };

    # Networking configuration
    networking = {
      inherit (config.networking) hostName;
      networkmanager_enabled = config.networking.networkmanager.enable or false;
      firewall_enabled = config.networking.firewall.enable;
      firewall_allowed_tcp = config.networking.firewall.allowedTCPPorts or [];
      nameservers = config.networking.nameservers or [];
    };

    # Users configuration
    users = {
      main_user_exists = builtins.hasAttr "schausberger" config.users.users;
      main_user_groups = config.users.users.schausberger.extraGroups or [];
      mutable_users = config.users.mutableUsers;
    };

    # Security configuration
    security = {
      sudo_enabled = config.security.sudo.enable;
      polkit_enabled = config.security.polkit.enable;
      rtkit_enabled = config.security.rtkit.enable;
      has_pam_sudo = builtins.hasAttr "sudo" config.security.pam.services;
      has_pam_systemd = builtins.hasAttr "systemd" config.security.pam.services;
    };

    # Critical systemd services
    systemd_services = {
      # Network services
      networkmanager =
        config.systemd.services.NetworkManager.enable
          or config.systemd.services.NetworkManager-wait-online.wantedBy or null;

      # System services
      dbus = builtins.hasAttr "dbus" config.systemd.services;
      systemd_timesyncd = builtins.hasAttr "systemd-timesyncd" config.systemd.services;

      # User services
      home_manager = builtins.hasAttr "home-manager-schausberger" config.systemd.services;
    };
  };
in {
  # Test all hosts
  desktop = getCriticalPaths "desktop" configs.desktop.config;
  portable = getCriticalPaths "portable" configs.portable.config;
  surface = getCriticalPaths "surface" configs.surface.config;
  hp-probook-vmware = getCriticalPaths "hp-probook-vmware" configs.hp-probook-vmware.config;
  hp-probook-wsl = getCriticalPaths "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = getCriticalPaths "m920q" configs.m920q.config;
}
