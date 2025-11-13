# WSL hardware configuration
# This file was generated for NixOS on WSL
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  # Set the host platform for nixpkgs
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Graphics support for WSL GUI applications
  hardware = {
    # Enable OpenGL for GUI applications
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Enable all firmware for better hardware support
    enableAllFirmware = true;
  };

  # GPU acceleration environment variables for WSLg
  # Required for Mesa D3D12 driver to find Windows GPU stack libraries
  environment.sessionVariables = {
    LD_LIBRARY_PATH = ["/run/opengl-driver/lib"];
    GALLIUM_DRIVER = "d3d12";
    MESA_LOADER_DRIVER_OVERRIDE = "d3d12";
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
  };

  # Virtualization settings
  virtualisation.docker.enable = true;

  # Network configuration for WSL (low level)
  networking = {
    # Let WSL manage IP addressing completely
    dhcpcd.enable = false;
    useNetworkd = false;
  };

  # File systems (WSL manages these automatically)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
