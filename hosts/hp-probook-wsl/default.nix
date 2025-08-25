{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [
    ../shared-tui.nix
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.default
    ../../system/core/persistence.nix
  ];

  config = {
    # Host-specific configuration
    hostConfig = {
      hostName = "hp-probook-wsl";
      user = "schausberger";
      wm = [];
      system = "x86_64-linux";
    };

    # Enable container tools for development
    modules.system.containers.enable = true;

    # Network configuration optimized for WSL
    networking = {
      # Set hostname
      hostName = "hp-probook-wsl";
      # Disable NetworkManager in WSL - let WSL handle networking
      networkmanager.enable = lib.mkForce false;
      # Let WSL manage networking completely
      dhcpcd.enable = false;
      # Disable systemd-resolved to avoid conflicts with WSL DNS
      resolvconf.enable = false;
      # Use WSL's DNS resolution
      nameservers = lib.mkForce [];
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

    # Hardware configuration for WSL
    hardware = {
      # Enable all firmware for better hardware support
      enableAllFirmware = true;
      # Note: graphics configuration is handled in hardware-configuration.nix
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

    # Home Manager configuration - import the hp-probook-wsl profile
    home-manager = {
      backupFileExtension = lib.mkForce "hm-backup";
      users.schausberger = {
        imports = [
          ../../home/profiles/hp-probook-wsl
        ];
      };
    };

    # WSL-specific system directories (override shared-tui paths)
    systemd.tmpfiles.rules = [
      "d /home/schausberger/mnt 0755 schausberger users -"
      "d /home/schausberger/mnt/gdrive 0755 schausberger users -"
    ];

    # Enable Windows integration features and recovery tools
    environment = {
      # Prevent NixOS from trying to manage /etc/nixos since we have our config there
      etc.nixos.enable = false;

      systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
        # WSL utilities
        nix-ld # Run unpatched dynamic binaries on NixOS
        wslu # WSL utilities for integration

        # WSL-specific recovery tools
        util-linux # Essential: mount, umount, lsblk

        # Network recovery
        inetutils # Essential: ping, traceroute for basic connectivity
        dnsutils # Essential: dig, nslookup for DNS debugging

        # System recovery essentials
        psmisc # killall, pstree (complement pik from TUI)
        strace # System call tracing (debugging tool)
        lsof # List open files (essential for debugging)
      ];
    };
  };
}
