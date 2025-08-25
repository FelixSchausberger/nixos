{inputs, ...}: let
  hostLib = import ../lib.nix;
  # WSL2 supports GUI applications through WSLg (Wayland-based)
  wms = ["hyprland"];
in {
  imports =
    [
      ../shared.nix
      ./hardware-configuration.nix
      inputs.nixos-wsl.nixosModules.default
    ]
    ++ hostLib.wmModules wms;

  # Host-specific configuration
  hostConfig = {
    hostName = "hp-probook-wsl";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # WSL-specific configuration
  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = false;
      network.generateHosts = false;
    };
    defaultUser = "schausberger";
    startMenuLaunchers = true;

    # Enable integration with Docker Desktop (if needed)
    docker-desktop.enable = false;
  };

  # Enable audio support for GUI applications
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable container tools for development
  modules.system.containers.enable = true;

  # Network configuration optimized for WSL
  networking = {
    # Use NetworkManager for consistent network handling
    networkmanager.enable = true;
    dhcpcd.enable = false;
  };

  # Boot optimizations for WSL
  systemd.services = {
    # Don't wait for network-online for faster boot
    "NetworkManager-wait-online".enable = false;
  };

  # Hardware configuration for work laptop
  hardware = {
    # Enable all firmware for better hardware support
    enableAllFirmware = true;
  };

  # System maintenance and monitoring (work laptop)
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = false; # Disable auto-updates in WSL environment
    monitoring = {
      enable = true;
      alerts = false; # Disable alerts in WSL
    };
  };

  # Enable Windows integration features
  environment.systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
    # WSL utilities
    wslu # WSL utilities for integration

    # Development tools commonly needed in WSL
    git
    vim
    curl
    wget
  ];
}
