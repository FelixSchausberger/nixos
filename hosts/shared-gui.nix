{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Shared configuration for GUI hosts (desktop, surface, work machines)
  # This module provides common functionality for systems with desktop environments

  imports = [
    ./boot-zfs.nix
    ../modules/system/gui.nix
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

        isGui = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this is a GUI system (should be true for GUI hosts)";
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
    description = "Host-specific configuration options for GUI systems";
  };

  config = let
    cfg = config.hostConfig;
  in {
    # Pass hostConfig to all modules
    _module.args = {inherit (config) hostConfig;};

    # Set networking hostname
    networking.hostName = cfg.hostName;

    # Full hardware graphics configuration for GUI systems
    hardware.graphics = lib.mkDefault {
      enable = true;
      enable32Bit = true;
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
