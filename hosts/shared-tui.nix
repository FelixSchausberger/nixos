{lib, ...}: {
  # Shared configuration for TUI-only hosts (WSL, headless, portable emergency)
  # This module provides common functionality for systems without GUI

  imports = [
    ./shared.nix
    ../modules/system/tui.nix
  ];

  config = {
    # Minimal hardware graphics configuration (for basic compatibility)
    hardware.graphics = lib.mkDefault {
      enable = false; # Disabled for TUI-only systems
      enable32Bit = false;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
