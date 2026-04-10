{lib, ...}: {
  # Shared configuration for TUI-only hosts (WSL, headless, portable emergency)
  # This module provides common functionality for systems without GUI

  imports = [
    ./shared.nix
    ../modules/system/tui.nix
  ];

  config = {
    # Overrides shared.nix mkDefault (priority 1000) without blocking host-level overrides.
    # Plain assignments in host configs (priority 100) still take precedence.
    hardware.graphics = lib.mkOverride 999 {
      enable = false;
      enable32Bit = false;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
