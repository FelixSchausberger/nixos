{
  lib,
  config,
  inputs,
  ...
}: {
  # Shared configuration for TUI-only hosts (WSL, headless, portable emergency)
  # This module provides common functionality for systems without GUI

  imports = [
    ../modules/system/tui.nix
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
          description = "List of window managers/desktop environments to enable (should be empty for TUI)";
        };

        system = lib.mkOption {
          type = lib.types.str;
          default = "x86_64-linux";
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

    # Create netrc file for nix GitHub access
    sops.templates."nix/netrc" = {
      content = ''
        machine github.com
        login token
        password ${config.sops.placeholder."github/token"}
      '';
      mode = "0600";
      path = "/etc/nix/netrc";
    };
  };
}
