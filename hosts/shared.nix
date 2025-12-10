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

        isGui = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host enables a graphical session";
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

        performanceProfile = lib.mkOption {
          type = lib.types.enum ["default" "gaming" "productivity" "power-saving"];
          default = "default";
          description = "Performance profile for this system";
        };

        specialisations = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
            options = {
              wm = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = "Window managers for this specialisation (null = inherit from parent)";
              };

              profile = lib.mkOption {
                type = lib.types.enum ["default" "gaming" "productivity" "power-saving"];
                default = "default";
                description = "Performance profile for this specialisation";
              };

              extraConfig = lib.mkOption {
                type = lib.types.deferredModule;
                default = {};
                description = "Additional NixOS configuration for this specialisation";
              };
            };
          }));
          default = {};
          description = "Specialisation definitions for this host";
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

    # Ensure configuration repo is in persistent location for ZFS impermanence
    system.activationScripts.checkConfigLocation = lib.mkIf (lib.hasAttr "persistence" config.environment) {
      text = ''
        EXPECTED_PATH="${defaults.paths.nixosConfig}"
        if [ ! -d "$EXPECTED_PATH" ]; then
          echo "WARNING: NixOS configuration not found at $EXPECTED_PATH" >&2
          echo "With ZFS impermanence, the config should be in the persistent /per directory." >&2
          echo "Current config will be lost on reboot!" >&2
          echo "" >&2
          echo "To fix this, run:" >&2
          echo "  git clone https://github.com/FelixSchausberger/nixos.git $EXPECTED_PATH" >&2
          echo "  cd $EXPECTED_PATH" >&2
          echo "  sudo nixos-rebuild switch --flake .#${cfg.hostName}" >&2
        fi
      '';
    };

    # Sops configuration and tmpfiles are now centralized in sops-common.nix
  };
}
