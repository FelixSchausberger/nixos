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

  # Enable all firmware for better hardware support
  hardware.enableAllFirmware = true;

  # Virtualization settings managed in modules/system/containers.nix
  # (Docker configuration optimized for boot performance)

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
