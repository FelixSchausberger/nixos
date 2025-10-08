# Test: portable host configuration builds correctly
{flake, ...}: let
  # Get the portable configuration from the flake
  inherit (flake.nixosConfigurations.portable) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: System is TUI-only (emergency/recovery system)
  is_gui = config.hostConfig.isGui;
  wm_count = builtins.length config.hostConfig.wm;

  # Test: NetworkManager enabled for WiFi
  networkmanager_enabled = config.networking.networkmanager.enable;

  # Test: Firewall disabled for recovery scenarios
  firewall_disabled = !config.networking.firewall.enable;

  # Test: Docker enabled for development
  docker_enabled = config.virtualisation.docker.enable;
  docker_on_boot = config.virtualisation.docker.enableOnBoot;

  # Test: Libvirtd enabled for virtualization
  libvirtd_enabled = config.virtualisation.libvirtd.enable;

  # Test: OpenSSH enabled for remote access
  openssh_enabled = config.services.openssh.enable;
  ssh_password_auth = config.services.openssh.settings.PasswordAuthentication;

  # Test: Rescue user exists
  rescue_user_exists = builtins.hasAttr "rescue" config.users.users;

  # Test: Graphics enabled for better hardware compatibility
  graphics_enabled = config.hardware.graphics.enable;
  graphics_32bit_enabled = config.hardware.graphics.enable32Bit;

  # Test: Main user in docker group
  schausberger_in_docker = builtins.elem "docker" config.users.users.schausberger.extraGroups;
}
