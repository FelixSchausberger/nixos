{inputs, ...}: {
  # Base configuration for Desktop host and specialisations
  # This module contains all shared configuration except WM modules and specialisation definitions
  # Note: disko.nix is NOT imported here as it's not needed in specialisations
  imports = [
    ../shared-gui.nix
    inputs.stylix.nixosModules.stylix
    ../../modules/system/stylix-catppuccin.nix
    ../../modules/system/performance-profiles.nix
  ];

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

  # Note: Hardware-specific configuration (keyboard, GPU profiles) is set in
  # the main Desktop configuration, not in base-config.nix, as specialisations
  # don't need hardware reconfiguration.

  # Note: System maintenance and monitoring is set in the main Desktop
  # configuration, not in base-config.nix, as specialisations inherit the
  # parent's systemd services.

  # Nix build optimizations for desktop (Ryzen 5 5600: 6C/12T)
  nix.settings = {
    max-jobs = 6; # Parallel derivation builds (one per physical core)
    cores = 12; # Parallel jobs within each build (all threads)

    # Build performance
    keep-outputs = false; # Don't keep build outputs (saves disk)
    keep-derivations = false; # Don't keep .drv files
    auto-optimise-store = true; # Hardlink identical files
  };

  # Use tmpfs for Nix builds (desktop has 16GB RAM)
  # Significantly speeds up compilation with RAM-backed builds
  systemd.services.nix-daemon.environment = {
    TMPDIR = "/tmp/nix-build";
  };
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root - -"
  ];
}
