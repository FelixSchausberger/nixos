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
    inputs.sopswarden.nixosModules.default
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

    # Enable sopswarden for secrets management
    services.sopswarden = {
      enable = true;
      sopsFile = "/per/etc/nixos/secrets/secrets.yaml";
      ageKeyFile = "/per/system/sops-key.txt";
      secrets = {
        # API tokens
        "claude/default" = "Claude API Token";
        "github/token" = "GitHub Personal Access Token";

        # AWS credentials
        "awscli/id" = "AWS CLI Access Key ID";
        "awscli/key" = "AWS CLI Secret Access Key";

        # Cloud storage
        "rclone/client-secret" = "rclone OAuth Client Secret";
        "rclone/token" = "rclone OAuth Token";

        # User credentials
        "schausberger/id_ed25519" = "SSH Private Key";

        # SSH authorized keys
        "ssh/authorized_keys/regular" = "SSH Authorized Keys Regular";

        # WiFi passwords
        "wifi/hochbau-talstation" = "WiFi Hochbau Talstation";
        "wifi/magenta-766410" = "WiFi Magenta 766410";
      };
    };

    # Configure sops-nix to use the same file that sopswarden manages
    sops = {
      defaultSopsFile = "/per/etc/nixos/secrets/secrets.yaml";
      age.keyFile = "/per/system/sops-key.txt";
    };
  };
}
