# WSL hardware configuration
# This file was generated for NixOS on WSL
{modulesPath, ...}: {
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  # Enable WSL compatibility
  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = false;
      network.generateHosts = false;
    };
    defaultUser = "schausberger";
    startMenuLaunchers = true;

    # Enable integration with Docker Desktop (if installed)
    docker-desktop.enable = false;

    # Enable GUI applications support through WSLg
    useWindowsDriver = true;
  };

  # Graphics support for WSL GUI applications
  hardware = {
    # Enable OpenGL for GUI applications
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  # Virtualization settings
  virtualisation.docker.enable = true;

  # Network configuration for WSL
  networking = {
    dhcpcd.enable = false;
    useNetworkd = true;
  };

  # File systems (WSL manages these automatically)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # System state version
  system.stateVersion = "24.05";
}
