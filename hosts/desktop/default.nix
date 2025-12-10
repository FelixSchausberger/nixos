{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports =
    [
      ./disko.nix
      ../shared-gui.nix
      inputs.stylix.nixosModules.stylix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/performance-profiles.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;
    # user and system use defaults from lib/defaults.nix

    # Define specialisations for this host
    specialisations = {
      # Single WM configurations for testing
      gnome-only = {
        wms = ["gnome"];
        profile = "productivity";
      };

      hyprland-only = {
        wms = ["hyprland"];
        profile = "default";
      };

      hyprland-gaming = {
        wms = ["hyprland"];
        profile = "gaming";
      };

      niri-only = {
        wms = ["niri"];
        profile = "default";
      };

      niri-portable = {
        wms = ["niri"];
        profile = "power-saving";
      };

      # Build-optimized configuration for compilation workloads
      build-optimized = {
        wms = ["hyprland"];
        profile = "productivity";
      };
    };
  };

  # Stylix theme management using Catppuccin Mocha
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

    # Enable targets for GUI apps
    targets = {
      # Console/TTY theming
      console.enable = true;

      # GUI applications
      gtk.enable = true;

      # Disable QT theming since we manage it manually via shared-environment.nix
      qt.enable = false;
    };
  };

  # Hardware configuration
  hardware = {
    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;

    # AMD RX 6700XT GPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
    };
  };

  # Nix build optimizations for desktop (Ryzen 5 5600: 6C/12T)
  nix.settings = {
    max-jobs = lib.mkForce 6; # Parallel derivation builds (one per physical core)
    cores = lib.mkForce 12; # Parallel jobs within each build (all threads)

    # Build performance
    keep-outputs = lib.mkForce false; # Don't keep build outputs (saves disk)
    keep-derivations = lib.mkForce false; # Don't keep .drv files
    auto-optimise-store = lib.mkForce true; # Hardlink identical files
  };

  # Use tmpfs for Nix builds (desktop has 16GB RAM)
  # Significantly speeds up compilation with RAM-backed builds
  systemd.services.nix-daemon.environment = {
    TMPDIR = "/tmp/nix-build";
  };
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root - -"
  ];

  # System specialisations for testing different configurations
  # These allow switching between configurations without full rebuilds
  # Usage: sudo nixos-rebuild switch --flake . --specialisation <name>
  #
  # Note: Specialisations are currently disabled due to conflicts when forcing
  # single WM configurations while inheriting multi-WM parent config.
  # The issue is that WM modules set conflicting options (e.g., PAM settings)
  # and simply using mkForce on hostConfig.wm isn't sufficient to disable
  # the other WM modules' settings.
  #
  # To properly implement single-WM specialisations, we would need to:
  # 1. Not use inheritParentConfig = true
  # 2. Manually re-import all base system configs
  # 3. Import only the desired WM module
  #
  # For now, to test individual WMs, temporarily modify hostConfig.wm in
  # hosts/desktop/default.nix directly.

  # specialisation = {
  #   # GNOME-only configuration
  #   gnome-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["gnome"];
  #     };
  #   };
  #
  #   # Hyprland-only configuration
  #   hyprland-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["hyprland"];
  #     };
  #   };
  #
  #   # Niri-only configuration
  #   niri-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["niri"];
  #     };
  #   };
  # };
}
