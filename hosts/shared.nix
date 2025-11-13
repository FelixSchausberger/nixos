{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Shared configuration helper for all hosts
  # This module provides common functionality used across all host configurations

  imports = [
    ./boot-zfs.nix
    ../modules/system
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
          description = "List of window managers/desktop environments to enable";
          example = ["gnome" "hyprland"];
        };

        system = lib.mkOption {
          type = lib.types.str;
          default = defaults.system.architecture;
          description = "System architecture";
        };

        autoLogin = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable automatic login";
              };

              user = lib.mkOption {
                type = lib.types.str;
                description = "User to automatically log in";
              };
            };
          });
          default = null;
          description = "Auto-login configuration";
        };
      };
    };
    description = "Host-specific configuration options";
  };

  config = let
    cfg = config.hostConfig;
  in {
    # Pass hostConfig to all modules
    _module.args = {inherit (config) hostConfig;};

    # Set networking hostname
    networking.hostName = cfg.hostName;

    # Basic hardware graphics configuration
    hardware.graphics = lib.mkDefault {
      enable = true;
      enable32Bit = true;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
