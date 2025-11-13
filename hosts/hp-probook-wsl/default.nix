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
      inputs.nixos-wsl.nixosModules.default
      inputs.stylix.nixosModules.stylix
      ../../modules/system/backup.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  config = {
    # Central WSL configuration (including mirrored networking + DNS)
    wsl = {
      enable = true;

      # All wslConf options defined once here
      wslConf = {
        automount.root = "/mnt";

        interop.appendWindowsPath = false;
        interop.enabled = true;

        network.generateHosts = false; # Do not let WSL overwrite /etc/hosts
        network.generateResolvConf = true;
        network.hostname = hostName;

        user.default = config.hostConfig.user;
      };

      defaultUser = config.hostConfig.user;
      startMenuLaunchers = true;

      # Enable interop for Windows binary execution
      interop.includePath = true;

      # Integration with Docker Desktop disabled (using native docker)
      docker-desktop.enable = false;

      # Enable GUI applications support through WSLg
      useWindowsDriver = true;
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

      targets = {
        console.enable = true;
        gtk.enable = true;
        qt.enable = false;
      };
    };

    # WSL uses its own boot mechanism, disable systemd-boot from shared-gui.nix
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # Override minimal profile settings for GUI support
    xdg.mime.enable = lib.mkForce true;
    xdg.icons.enable = lib.mkForce true;
    xdg.autostart.enable = lib.mkForce true;
    xdg.sounds.enable = lib.mkForce true;

    # Emergency recovery user - minimal shell, no customization
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

    # Network configuration optimized for WSL (high level)
    networking = {
      inherit hostName;
      # Disable NetworkManager in WSL
      networkmanager.enable = lib.mkForce false;
    };

    # systemd tweaks for WSL
    systemd = {
      services = {
        "NetworkManager-wait-online".enable = false;
        "systemd-networkd-wait-online".enable = lib.mkForce false;
        "smartd".enable = false;

        # Create DRI devices for WSL2 GPU access
        "wsl-dri-devices" = {
          description = "Create DRI device nodes for WSL2";
          wantedBy = ["multi-user.target"];
          before = ["display-manager.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            # Create /dev/dri directory
            mkdir -p /dev/dri

            # Create render node with proper permissions
            if [ ! -c /dev/dri/renderD128 ]; then
              mknod -m 666 /dev/dri/renderD128 c 226 128
            else
              chmod 666 /dev/dri/renderD128
            fi

            # Create card0 device
            if [ ! -c /dev/dri/card0 ]; then
              mknod -m 666 /dev/dri/card0 c 226 0
            else
              chmod 666 /dev/dri/card0
            fi

            echo "Created DRI devices for WSL2"
          '';
        };
      };

      # WSL-specific system directories (override shared-tui paths)
      tmpfiles.rules = let
        inherit (inputs.self.lib.defaults.system) user;
      in [
        "d /home/${user}/mnt 0755 ${user} users -"
        "d /home/${user}/mnt/gdrive 0755 ${user} users -"
        # Create /dev/dri directory and set permissions
        "d /dev/dri 0755 root root -"
        "c /dev/dri/renderD128 0666 root root - 226:128"
        "c /dev/dri/card0 0666 root root - 226:0"
      ];
    };

    # Environment packages and tools
    environment = {
      systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
        nix-ld
        wslu
        powershell

        util-linux
        inetutils
        dnsutils

        psmisc
        strace
        lsof
      ];

      sessionVariables = {
        # Ensure niri uses the nested winit backend inside WSLg instead of DRM/KMS
        NIRI_BACKEND = "winit";
        WINIT_UNIX_BACKEND = "wayland";
      };
    };

    # Nix configuration for WSL
    nix = {
      settings = {
        auto-optimise-store = true;
        experimental-features = ["nix-command" "flakes"];
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

    # Configure nix-ld with GUI application dependencies for WSL2
    programs.nix-ld = {
      enable = true;
      libraries = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
        gtk3
        alsa-lib
        xorg.libX11
        xorg.libxcb

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

        pipewire
        libpulseaudio

        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXrandr
        xorg.libXScrnSaver
        xorg.libXtst
        libxkbcommon

        libuuid
        at-spi2-atk
        at-spi2-core
      ];
    };
  };
}
