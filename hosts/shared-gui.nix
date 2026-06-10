# Shared baseline for GUI-capable hosts.
# Combines common host defaults, ZFS boot behavior, and system GUI module imports.
{lib, ...}: {
  # Shared configuration for GUI hosts (desktop, surface, work machines)
  # This module provides common functionality for systems with desktop environments

  imports = [
    ./shared.nix
    ./boot-zfs.nix
    ../modules/system/gui.nix
  ];

  config = {
    # Full hardware graphics configuration for GUI systems
    hardware.graphics = lib.mkDefault {
      enable = true;
      enable32Bit = true;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
