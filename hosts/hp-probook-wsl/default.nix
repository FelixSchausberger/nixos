# WSL2 headless host with NixOS userland, corporate CA integration, and TUI tools.
# Replaces unsupported bare-metal features (ZFS/bootloader) with WSL-safe equivalents.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  hostName = "hp-probook-wsl";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports = [
    ../shared-tui.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.stylix.nixosModules.stylix
    ../../modules/system/stylix-catppuccin.nix
    ../../modules/system/wsl-integration.nix
    ../../modules/system/homelab/tailscale.nix
    ../../modules/vitals.nix
  ];
  config = {
    # Central WSL configuration (including mirrored networking + DNS)
    wsl = {
      enable = true;

      # All wslConf options defined once here
      wslConf = {
        automount.root = "/mnt";

        # Set to false to avoid Windows PATH pollution in Linux shells
        # Windows binaries are still accessible via interop.includePath
        # If you need Windows tools in PATH, set this to true
        interop.appendWindowsPath = false;
        interop.enabled = true;

        network.generateHosts = false; # Do not let WSL overwrite /etc/hosts
        network.generateResolvConf = true; # Let WSL generate /etc/resolv.conf for NAT-mode DNS
        network.hostname = hostName;

        user.default = config.hostConfig.user;
      };

      defaultUser = config.hostConfig.user;

      # Enable interop for Windows binary execution
      interop.includePath = true;

      # Integration with Docker Desktop disabled (using native docker)
      docker-desktop.enable = false;

      # WSLg disabled — this is a headless/TUI-only environment
    };

    # ESET SSL Filter CA certificate from sops
    sops.secrets."eset-root.pem" = {
      owner = "root";
      mode = "0444";
    };

    # Systemd service to create ESET-enhanced CA bundle at boot
    # Runs after sops secrets are available, before nix-daemon starts
    systemd.services.eset-ca-bundle = {
      description = "Create CA bundle with ESET SSL Filter cert";
      wantedBy = ["multi-user.target"];
      before = ["nix-daemon.service"];
      after = ["sops-nix.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Create composed bundle in /run (tmpfs, writable)
        umask 022
        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
            ${config.sops.secrets."eset-root.pem".path} \
          > /run/ca-bundle-plus-eset.pem
        chmod 644 /run/ca-bundle-plus-eset.pem
        echo "Created ESET-enhanced CA bundle at /run/ca-bundle-plus-eset.pem"
      '';
    };

    # Host-specific configuration using centralized host mapping
    hostConfig = {
      inherit hostName;
      inherit (hostInfo) isGui;
      inherit (hostInfo) wms;
      # user and system use defaults from lib/defaults.nix
    };

    modules.system.stylix-catppuccin.enable = true;

    services.vitals = {
      enable = true;
      headless = true;
    };

    # WSL uses its own boot mechanism, disable systemd-boot from shared-gui.nix
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # Disable ZFS configuration from boot-zfs.nix (WSL kernel doesn't support ZFS)
    boot.supportedFilesystems = lib.mkForce ["ntfs"];
    boot.zfs.extraPools = lib.mkForce [];
    services.zfs.autoScrub.enable = lib.mkForce false;
    services.zfs.autoSnapshot.enable = lib.mkForce false;

    # WSL uses ext4, not ZFS - disable persistence from system/core
    environment.persistence = lib.mkForce {};

    # XDG not needed — headless TUI environment

    # Emergency recovery user - minimal shell, no customization
    users.users.emergency = {
      isNormalUser = true;
      description = "Emergency recovery account";
      shell = pkgs.bash;
      extraGroups = ["wheel"]; # sudo access for recovery
      hashedPasswordFile = config.sops.secrets."private/password-hash".path;
      home = "/home/emergency";
    };

    # Enable user lingering for systemctl --user support (required for home-manager activation)
    # Previously disabled due to SIGCHLD issues with the GUI shell wrapper; safe now that WSL is headless.
    users.users.${config.hostConfig.user}.linger = true;

    # Merged modules configuration
    modules.system = {
      containers.enable = true;
      wsl-integration.enable = true;
      homelab.tailscale.enable = true;
      maintenance = {
        enable = true;
        autoUpdate.enable = false; # Disable auto-updates in WSL environment
        monitoring = {
          enable = true;
          alerts = false; # Disable alerts in WSL
        };
      };
      deploymentValidation = {
        essentialPaths = [
          "/run/current-system/sw/bin/bash"
          "/run/current-system/sw/bin/systemctl"
          "/nix/store"
          # /etc/nixos removed - not applicable in WSL (config is at /per/etc/nixos)
        ];
      };
    };

    # Network configuration optimized for WSL (high level)
    networking = {
      inherit hostName;
      # Static nameservers removed — WSL generates /etc/resolv.conf in NAT mode
      nameservers = lib.mkForce [];
      # Disable NetworkManager in WSL
      networkmanager.enable = lib.mkForce false;
    };

    # systemd tweaks for WSL
    systemd = {
      services = {
        "NetworkManager-wait-online".enable = false;
        "systemd-networkd-wait-online".enable = lib.mkForce false;
        "smartd".enable = false;
      };

      # WSL-specific system directories (override shared-tui paths)
      tmpfiles.rules = let
        inherit (inputs.self.lib.defaults.system) user;
        uid = "1000"; # schausberger user ID (WSL base image UID)
      in [
        "d /home/${user}/mnt 0755 ${user} users -"
        "d /home/${user}/mnt/gdrive 0755 ${user} users -"
        # NOTE: XDG_RUNTIME_DIR is usually created automatically by systemd
        # This is a fallback to ensure it exists for WSL edge cases
        "d /run/user/${uid} 0700 ${user} users -"
        # Ensure sops key is readable by user (required for user-level sops-nix)
        "Z /per/system/sops-key.txt 0644 root root -"
      ];
    };

    # Environment packages and tools
    environment = {
      systemPackages = with pkgs; [
        util-linux
        inetutils
        dnsutils

        psmisc
        strace
        lsof
      ];

      # No GUI session variables — headless TUI environment
    };

    # Nix configuration for WSL
    nix = {
      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        connect-timeout = lib.mkForce 10;

        # Use ESET-enhanced bundle (created by systemd service at boot)
        ssl-cert-file = lib.mkForce "/run/ca-bundle-plus-eset.pem";
      };

      extraOptions = ''
        keep-env-derivations = true
        keep-outputs = true
      '';
    };

    # Git configuration to use ESET-enhanced bundle
    programs.git = {
      enable = true;
      config.http.sslCAInfo = "/run/ca-bundle-plus-eset.pem";
    };

    # nix-ld not needed — no GUI applications in headless TUI environment
  };
}
