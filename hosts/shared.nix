{
  lib,
  config,
  inputs,
  ...
}: {
  # Shared configuration helper for all hosts
  # This module provides common functionality used across all host configurations

  imports = [
    ./boot-zfs.nix
    ../modules/system
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
          default = "schausberger";
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
          default = "x86_64-linux";
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

    # Configure sops-nix for secrets management
    sops = {
      defaultSopsFile = ../secrets/secrets.yaml;
      age.keyFile = "/per/system/sops-key.txt";
      secrets = {
        # API tokens
        "claude/default" = {};
        "github/token" = {};

        # Cloud storage
        "rclone/client-secret" = {};
        "rclone/token" = {};

        # Bitwarden master password
        "bitwarden/master-password" = {};

        # SSH authorized keys
        "ssh/authorized_keys/magazino" = {};

        # Host-specific secrets (available in shared file for pdemu1cml000312)
        "awscli/id" = {};
        "awscli/key" = {};
        "gitlab/token" = {};
        "magazino/email" = {};
        "magazino/vault-token" = {};
        "vpn/auth" = {};
        "vpn/ca.crt" = {};
        "vpn/client.crt" = {};
        "vpn/key" = {};
      };
    };
  };
}
