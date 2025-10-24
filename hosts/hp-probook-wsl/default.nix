{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  wms = ["niri"];
in {
  imports =
    [
      ../shared-gui.nix
      ./hardware-configuration.nix
      inputs.nixos-wsl.nixosModules.default
    ]
    ++ hostLib.wmModules wms;

  config = {
    # Home Manager configuration
    home-manager.users.schausberger = {
      imports = [
        ../../home/profiles/hp-probook-wsl
      ];
    };

    # Host-specific configuration
    hostConfig = {
      hostName = "hp-probook-wsl";
      user = "schausberger";
      isGui = true;
      wm = wms;
      system = "x86_64-linux";
    };

    # WSL uses its own boot mechanism, disable systemd-boot from shared-gui.nix
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # Emergency recovery user - minimal shell, no customization
    # Access with: wsl -u emergency
    users.users.emergency = {
      isNormalUser = true;
      description = "Emergency recovery account";
      shell = inputs.nixpkgs.legacyPackages.x86_64-linux.bash;
      extraGroups = ["wheel"]; # sudo access for recovery
      hashedPassword = "$6$rounds=656000$cUk4Xh8KRvx9lTkN$OyVJ7QXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQ"; # Password: emergency (change after first login)
      home = "/home/emergency";
    };

    # Merged modules configuration
    modules.system = {
      containers.enable = true;
      wsl-integration.enable = true;
      maintenance = {
        enable = true;
        autoUpdate.enable = false; # Disable auto-updates in WSL environment
        monitoring = {
          enable = true;
          alerts = false; # Disable alerts in WSL
        };
      };
    };

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

    # Merged systemd configuration
    systemd = {
      # Boot optimizations for WSL
      services = {
        # Don't wait for network-online for faster boot
        "NetworkManager-wait-online".enable = false;
        # Disable systemd-networkd-wait-online in WSL (force override)
        "systemd-networkd-wait-online".enable = lib.mkForce false;
        # Disable smartd in WSL as it fails on virtual disks
        "smartd".enable = false;

        # Configure Nix daemon with SSL certificate environment variables (prefer enhanced bundle)
        nix-daemon = {
          environment = {
            NIX_SSL_CERT_FILE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
            SSL_CERT_FILE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
            CURL_CA_BUNDLE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
          };
        };
      };

      # WSL-specific system directories (override shared-tui paths)
      tmpfiles.rules = [
        "d /home/schausberger/mnt 0755 schausberger users -"
        "d /home/schausberger/mnt/gdrive 0755 schausberger users -"
      ];
    };

    # Hardware configuration for WSL
    hardware = {
      # Enable all firmware for better hardware support
      enableAllFirmware = true;
      # Note: graphics configuration is handled in hardware-configuration.nix
    };

    # Enable Windows integration features and recovery tools
    # SSL certificate configuration for WSL
    security.pki.certificateFiles = [
      "${inputs.nixpkgs.legacyPackages.x86_64-linux.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];

    # Merged environment configuration
    environment = {
      # Ensure proper SSL certificate paths in /etc (with fallback to standard certificates)
      etc = {
        "ssl/certs/ca-bundle.crt".source = lib.mkDefault "${inputs.nixpkgs.legacyPackages.x86_64-linux.cacert}/etc/ssl/certs/ca-bundle.crt";
        "ssl/certs/ca-certificates.crt".source = lib.mkDefault "${inputs.nixpkgs.legacyPackages.x86_64-linux.cacert}/etc/ssl/certs/ca-bundle.crt";
      };

      # SSL/TLS certificate environment variables for WSL (prefer enhanced bundle)
      variables = {
        SSL_CERT_FILE = lib.mkDefault "/etc/ssl/certs/ca-bundle-enhanced.crt";
        SSL_CERT_DIR = lib.mkDefault "/etc/ssl/certs";
        CURL_CA_BUNDLE = lib.mkDefault "/etc/ssl/certs/ca-bundle-enhanced.crt";
        NIX_SSL_CERT_FILE = lib.mkDefault "/etc/ssl/certs/ca-bundle-enhanced.crt";
        # Additional certificate environment variables for various tools
        GIT_SSL_CAINFO = lib.mkDefault "/etc/ssl/certs/ca-bundle-enhanced.crt";
        NODE_EXTRA_CA_CERTS = lib.mkDefault "/etc/ssl/certs/ca-bundle-enhanced.crt";
      };

      # Global session variables for all user sessions (prefer enhanced bundle)
      sessionVariables = {
        SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-enhanced.crt";
        SSL_CERT_DIR = "/etc/ssl/certs";
        CURL_CA_BUNDLE = "/etc/ssl/certs/ca-bundle-enhanced.crt";
        NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-enhanced.crt";
        GIT_SSL_CAINFO = "/etc/ssl/certs/ca-bundle-enhanced.crt";
        NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-bundle-enhanced.crt";
      };

      systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
        # SSL/TLS certificate packages
        cacert # CA certificates bundle

        # WSL utilities
        nix-ld # Run unpatched dynamic binaries on NixOS
        wslu # WSL utilities for integration
        powershell # PowerShell for WSL notifications

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

    # Nix configuration for WSL with SSL certificate settings (prefer enhanced bundle)
    nix = {
      settings = {
        ssl-cert-file = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
        # Additional settings for better WSL networking
        auto-optimise-store = true;
        experimental-features = ["nix-command" "flakes"];
        # Prevent network timeouts in WSL
        connect-timeout = lib.mkForce 10;
      };

      # Extra options for Nix configuration
      extraOptions = ''
        ssl-cert-file = /etc/ssl/certs/ca-bundle-enhanced.crt
        keep-env-derivations = true
        keep-outputs = true
      '';
    };

    # Configure nix-ld with GUI application dependencies for WSL2
    programs.nix-ld = {
      enable = true;
      libraries = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
        # Core GUI dependencies (equivalent to Ubuntu packages)
        gtk3 # libgtk-3-0
        alsa-lib # libasound2
        xorg.libX11 # libx11-xcb support
        xorg.libxcb # libx11-xcb support

        # Additional GUI dependencies for browser support
        stdenv.cc.cc
        glib
        zlib
        fontconfig
        freetype
        cairo
        pango
        atk
        gdk-pixbuf
        libGL
        dbus
        nss
        nspr
        cups
        libdrm
        mesa
        expat

        # Audio/Media support
        pipewire
        libpulseaudio

        # X11/Wayland support
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXrandr
        xorg.libXScrnSaver
        xorg.libXtst
        libxkbcommon

        # Additional browser dependencies
        libuuid
        at-spi2-atk
        at-spi2-core
      ];
    };
  };
}
