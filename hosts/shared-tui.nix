{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Shared configuration for TUI-only hosts (WSL, headless, portable emergency)
  # This module provides common functionality for systems without GUI

  imports = [
    ../modules/system/tui.nix
    ../modules/system/sops-common.nix
    inputs.sops-nix.nixosModules.sops
  ];

  options.hostConfig = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The hostname for this system";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = defaults.system.user;
          description = "Primary user for this system";
        };

        wm = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "List of window managers/desktop environments to enable (should be empty for TUI)";
        };

        system = lib.mkOption {
          type = lib.types.str;
          default = defaults.system.architecture;
          description = "System architecture";
        };

        isGui = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is a GUI system (should be false for TUI hosts)";
        };
      };
    };
    description = "Host-specific configuration options for TUI systems";
  };

  config = {
    # Pass hostConfig to all modules
    _module.args = {inherit (config) hostConfig;};

    # Minimal hardware graphics configuration (for basic compatibility)
    hardware.graphics = lib.mkDefault {
      enable = false; # Disabled for TUI-only systems
      enable32Bit = false;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
