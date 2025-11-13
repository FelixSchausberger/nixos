{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "hp-probook-wsl";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports =
    [
      ../shared-tui.nix
      ./hardware-configuration.nix
      inputs.nixos-wsl.nixosModules.default
      inputs.stylix.nixosModules.stylix
      ../../modules/system/backup.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  config = {
    home-manager.users.${inputs.self.lib.defaults.system.user} = {
      imports = [
        ../../home/profiles/hp-probook-wsl
      ];
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
      wm = hostInfo.wms;
      # user and system use defaults from lib/defaults.nix
    };

    # Stylix configuration (PoC for TUI apps with Catppuccin theme)
    stylix = let
      inherit (inputs.self.lib) fonts;
      catppuccin = inputs.self.lib.catppuccinColors.mocha;
    in {
      enable = true;

      # Use Catppuccin Mocha colors via base16 scheme
      base16Scheme = {
        base00 = catppuccin.base; # Default background
        base01 = catppuccin.mantle; # Lighter background (status bars, line numbers)
        base02 = catppuccin.surface0; # Selection background
        base03 = catppuccin.surface1; # Comments, invisibles
        base04 = catppuccin.surface2; # Dark foreground (status bars)
        base05 = catppuccin.text; # Default foreground
        base06 = catppuccin.subtext1; # Light foreground
        base07 = catppuccin.subtext0; # Light background
        base08 = catppuccin.red; # Variables, XML tags
        base09 = catppuccin.peach; # Integers, booleans
        base0A = catppuccin.yellow; # Classes, search text
        base0B = catppuccin.green; # Strings
        base0C = catppuccin.teal; # Support, regex
        base0D = catppuccin.blue; # Functions, methods
        base0E = catppuccin.mauve; # Keywords, storage
        base0F = catppuccin.flamingo; # Deprecated, embedded
      };

      # Font configuration using centralized fonts
      fonts = {
        monospace = {
          package = inputs.nixpkgs.legacyPackages.x86_64-linux.nerd-fonts.jetbrains-mono;
          inherit (fonts.families.monospace) name;
        };
        sansSerif = {
          package = inputs.nixpkgs.legacyPackages.x86_64-linux.inter;
          inherit (fonts.families.sansSerif) name;
        };
        serif = {
          package = inputs.nixpkgs.legacyPackages.x86_64-linux.merriweather;
          inherit (fonts.families.serif) name;
        };
        sizes = {
          applications = fonts.sizes.normal;
          terminal = fonts.sizes.normal;
          desktop = fonts.sizes.normal;
          popups = fonts.sizes.normal;
        };
      };

      # Cursor theme using centralized configuration
      cursor = {
        package = inputs.nixpkgs.legacyPackages.x86_64-linux.bibata-cursors;
        inherit (fonts.cursor) name;
        inherit (fonts.cursor) size;
      };

      # Enable targets for TUI and GUI apps
      # Note: Stylix automatically enables most targets; manual configuration is minimal
      targets = {
        # Console/TTY theming
        console.enable = true;

        # GUI applications
        gtk.enable = true;

        # Disable QT theming since we manage it manually via shared-environment.nix
        qt.enable = false;
      };
    };

    # WSL uses its own boot mechanism, disable systemd-boot from shared-gui.nix
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # Override minimal profile settings for GUI support
    # The minimal profile disables XDG features, but niri requires them
    xdg.mime.enable = lib.mkForce true;
    xdg.icons.enable = lib.mkForce true;
    xdg.autostart.enable = lib.mkForce true;
    xdg.sounds.enable = lib.mkForce true;

    # Emergency recovery user - minimal shell, no customization
    # Access with: wsl -u emergency
    users.users.emergency = {
      isNormalUser = true;
      description = "Emergency recovery account";
      shell = inputs.nixpkgs.legacyPackages.x86_64-linux.bash;
      extraGroups = ["wheel"]; # sudo access for recovery
      hashedPassword = "$6$rounds=656000$cUk4Xh8KRvx9lTkN$OyVJ7QXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQXzXqZO5xFNPcGKP9XRQ";
      home = "/home/emergency";
    };

    # Merged modules configuration
    modules.system = {
      containers.enable = true;
      wsl-integration.enable = true;
      backup = {
        enable = true;
        backupDir = "D:/Backups/WSL-NixOS";
        retention = {
          fullBackups = 3;
          incrementalDays = 30;
        };
        schedule = {
          enable = false; # Disable systemd timer, use Windows Task Scheduler instead
        };
      };
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
    };

    wsl.wslConf = {
      network.generateResolvConf = true;
      automount.root = "/mnt";
      interop.appendWindowsPath = false;
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
      };

      # WSL-specific system directories (override shared-tui paths)
      tmpfiles.rules = let
        inherit (inputs.self.lib.defaults.system) user;
      in [
        "d /home/${user}/mnt 0755 ${user} users -"
        "d /home/${user}/mnt/gdrive 0755 ${user} users -"
      ];
    };

    # Hardware configuration for WSL
    hardware = {
      # Enable all firmware for better hardware support
      enableAllFirmware = true;
      # Note: graphics configuration is handled in hardware-configuration.nix
    };

    # Enable Windows integration features and recovery tools

    # Merged environment configuration
    environment = {
      systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
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

    # Nix configuration for WSL
    nix = {
      settings = {
        # Additional settings for better WSL networking
        auto-optimise-store = true;
        experimental-features = ["nix-command" "flakes"];
        # Prevent network timeouts in WSL
        connect-timeout = lib.mkForce 10;
        # Use ESET-enhanced bundle (created by systemd service at boot)
        # Falls back to standard bundle if not yet created
        ssl-cert-file = lib.mkForce "/run/ca-bundle-plus-eset.pem";
      };

      # Extra options for Nix configuration
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
