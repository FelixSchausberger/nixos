{lib, ...}: {
  # Shared configuration for GUI hosts (desktop, surface, work machines)
  # This module provides common functionality for systems with desktop environments

  imports = [
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
