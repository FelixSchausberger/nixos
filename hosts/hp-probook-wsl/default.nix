{
  inputs,
  lib,
  config,
  ...
}: let
  hostLib = import ../lib.nix;
  # WSL2 supports GUI applications through WSLg (Wayland-based)
  wms = ["hyprland"];
in {
  # Define hostConfig option (from shared.nix)
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
        };
        system = lib.mkOption {
          type = lib.types.str;
          default = "x86_64-linux";
          description = "System architecture";
        };
      };
    };
    description = "Host-specific configuration options";
  };

  imports =
    [
      # Import shared config components but exclude boot-zfs.nix for WSL
      ../../modules/system
      inputs.sops-nix.nixosModules.sops
      ./hardware-configuration.nix
      inputs.nixos-wsl.nixosModules.default
    ]
    ++ hostLib.wmModules wms;

  config = {
    # Host-specific configuration
    hostConfig = {
      hostName = "hp-probook-wsl";
      user = "schausberger";
      wm = wms;
      system = "x86_64-linux";
    };

    # WSL-specific configuration
    wsl = {
      enable = true;
      wslConf = {
        automount.root = "/mnt";
        interop.appendWindowsPath = false;
        network.generateHosts = false;
        network.generateResolvConf = false;
      };
      defaultUser = "schausberger";
      startMenuLaunchers = true;

      # Enable integration with Docker Desktop (if needed)
      docker-desktop.enable = false;
    };

    # Prevent NixOS from trying to manage /etc/nixos since we have our config there
    environment.etc.nixos.enable = false;

    # Enable audio support for GUI applications
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Enable container tools for development
    modules.system.containers.enable = true;

    # Network configuration optimized for WSL
    networking = {
      # Use NetworkManager for consistent network handling
      networkmanager.enable = true;
      dhcpcd.enable = false;
    };

    # Boot optimizations for WSL
    systemd.services = {
      # Don't wait for network-online for faster boot
      "NetworkManager-wait-online".enable = false;
      # Disable systemd-networkd-wait-online in WSL (force override)
      "systemd-networkd-wait-online".enable = lib.mkForce false;
      # Disable smartd in WSL as it fails on virtual disks
      "smartd".enable = false;
    };

    # Hardware configuration for work laptop
    hardware = {
      # Enable all firmware for better hardware support
      enableAllFirmware = true;
    };

    # System maintenance and monitoring (work laptop)
    modules.system.maintenance = {
      enable = true;
      autoUpdate.enable = false; # Disable auto-updates in WSL environment
      monitoring = {
        enable = true;
        alerts = false; # Disable alerts in WSL
      };
    };

    # Shared configuration elements (from shared.nix but WSL-compatible)
    # Pass hostConfig to all modules
    _module.args = {inherit (config) hostConfig;};

    # Set networking hostname
    networking.hostName = "hp-probook-wsl";

    # Basic hardware graphics configuration
    hardware.graphics = lib.mkDefault {
      enable = true;
      enable32Bit = true;
    };

    # Configure sops-nix for secrets management
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
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
      };
    };

    # Create system mount directories for rclone
    systemd.tmpfiles.rules = [
      "d /home/schausberger/mnt 0755 schausberger users -"
      "d /home/schausberger/mnt/gdrive 0755 schausberger users -"
    ];

    # Enable Windows integration features
    environment.systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
      # WSL utilities
      wslu # WSL utilities for integration

      # Development tools commonly needed in WSL
      git
      vim
      curl
      wget
    ];
  }; # End config
}
