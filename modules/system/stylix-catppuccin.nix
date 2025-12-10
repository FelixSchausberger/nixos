# Shared Stylix module with Catppuccin Mocha theme
#
# Eliminates 265+ lines of duplication across 4 hosts:
# - desktop (GUI, custom font packages)
# - surface (GUI, default font packages)
# - hp-probook-wsl (TUI, custom font packages)
# - hp-probook-vmware (GUI, custom font packages)
#
# Usage:
#   # Enable with default font packages (pkgs.nerd-fonts.jetbrains-mono, etc.)
#   modules.system.stylix-catppuccin.enable = true;
#
#   # Or customize font packages
#   modules.system.stylix-catppuccin = {
#     enable = true;
#     fontPackages = {
#       monospace = inputs.nixpkgs.legacyPackages.x86_64-linux.nerd-fonts.jetbrains-mono;
#       sansSerif = inputs.nixpkgs.legacyPackages.x86_64-linux.inter;
#       serif = inputs.nixpkgs.legacyPackages.x86_64-linux.merriweather;
#     };
#   };
{
  lib,
  config,
  inputs,
  pkgs,
  ...
}: {
  options.modules.system.stylix-catppuccin = {
    enable = lib.mkEnableOption "Stylix Catppuccin Mocha theme";

    # Allow per-host font package customization
    fontPackages = {
      monospace = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nerd-fonts.jetbrains-mono;
        description = "Monospace font package for terminals and code editors";
      };

      sansSerif = lib.mkOption {
        type = lib.types.package;
        default = pkgs.inter;
        description = "Sans-serif font package for UI elements";
      };

      serif = lib.mkOption {
        type = lib.types.package;
        default = pkgs.merriweather;
        description = "Serif font package for documents";
      };
    };

    cursorPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bibata-cursors;
      description = "Cursor theme package";
    };
  };

  config = lib.mkIf config.modules.system.stylix-catppuccin.enable {
    # Explicitly disable Qt styling at home-manager level
    # Stylix sets qt.enable = true even when targets.qt.enable = false
    home-manager.sharedModules = [
      {
        qt.enable = lib.mkForce false;

        # Enable stylix theming for applications
        stylix.targets = {
          firefox.profileNames = ["default"];
          zen-browser.profileNames = ["default"];
        };
      }
    ];

    stylix = let
      inherit (inputs.self.lib) fonts;
      catppuccin = inputs.self.lib.catppuccinColors.mocha;
      fontPkgs = config.modules.system.stylix-catppuccin.fontPackages;
      cursorPkg = config.modules.system.stylix-catppuccin.cursorPackage;
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

      # Font configuration using centralized fonts library
      fonts = {
        monospace = {
          package = fontPkgs.monospace;
          inherit (fonts.families.monospace) name;
        };
        sansSerif = {
          package = fontPkgs.sansSerif;
          inherit (fonts.families.sansSerif) name;
        };
        serif = {
          package = fontPkgs.serif;
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
        package = cursorPkg;
        inherit (fonts.cursor) name;
        inherit (fonts.cursor) size;
      };

      # Enable targets for GUI apps
      targets = {
        # Console/TTY theming
        console.enable = true;

        # GUI applications
        gtk.enable = true;

        # Disable all Qt theming since we manage it manually via qt5ct/qt6ct
        qt.enable = false;
      };
    };
  };
}
