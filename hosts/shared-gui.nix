{
  lib,
  config,
  inputs,
  ...
}: {
  # Shared configuration for GUI hosts (desktop, surface, work machines)
  # This module provides common functionality for systems with desktop environments

  imports = [
    ./boot-zfs.nix
    ../modules/system/gui.nix
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

    # Configure sops-nix for secrets management
    sops = {
      defaultSopsFile = ../secrets/secrets.yaml;
      age.keyFile = "/per/system/sops-key.txt";
      secrets = {
        # API tokens
        "claude/default" = {};
        "github/token" = {
          owner = "schausberger";
        };
        "cachix/token" = {};

        # Cloud storage
        "rclone/client-secret" = {};
        "rclone/token" = {};

        # Bitwarden master password
        "bitwarden/master-password" = {};

        # Personal information
        "schausberger/email" = {};
      };
    };

    # Create system mount directories for rclone
    systemd.tmpfiles.rules = [
      "d /per/mnt 0755 root root -"
      "d /per/mnt/gdrive 0755 root root -"
    ];

    # Create netrc file for nix GitHub and Cachix access
    sops.templates."nix/netrc" = {
      content = ''
        machine github.com
        login token
        password ${config.sops.placeholder."github/token"}

        machine nixpkgs-schausberger.cachix.org
        password ${config.sops.placeholder."cachix/token"}
      '';
      mode = "0600";
      path = "/etc/nix/netrc";
    };
  };
}
