# Shared Stylix module with a selectable base16 scheme
#
# The module keeps its historical name; `scheme` chooses Catppuccin Mocha,
# Everforest Dark or the monochrome ASCII palette. The shell targets, the
# custom stack and the GUI environment variables all read the same scheme.
#
# Eliminates 265+ lines of duplication across the GUI hosts and keeps the
# palette out of each host's configuration.
#
# Usage:
#   # Enable with default font packages (pkgs.nerd-fonts.jetbrains-mono, etc.)
#   modules.system.stylix-catppuccin.enable = true;
#
#   # Or customize font packages and the palette
#   modules.system.stylix-catppuccin = {
#     enable = true;
#     scheme = "everforest-dark";
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
}: let
  schemeColors = inputs.self.lib.themeSchemes.${config.modules.system.stylix-catppuccin.scheme};
in {
  options.modules.system.stylix-catppuccin = {
    enable = lib.mkEnableOption "Stylix theming with a selectable base16 scheme";

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

    scheme = lib.mkOption {
      type = lib.types.enum [
        "catppuccin-mocha"
        "everforest-dark"
        "ascii-mono"
      ];
      default = "catppuccin-mocha";
      description = ''
        Base16 scheme used by Stylix and the shell theme targets. The matching
        runtime wallpaper family is chosen separately with
        `wallpaper-theme <name>`; switching this option needs a rebuild.
      '';
    };
  };

  config = lib.mkIf config.modules.system.stylix-catppuccin.enable {
    # Explicitly disable Qt styling at home-manager level
    # Stylix sets qt.enable = true even when targets.qt.enable = false
    home-manager.sharedModules = [
      (
        {config, ...}: {
          qt.enable = lib.mkForce false;
          # Disable Stylix release check on HM side (tracks unstable, not a fixed release)
          stylix.enableReleaseChecks = false;

          # Home-manager 25.05+ deprecates relying on stylix's cursor config to
          # implicitly enable cursor generation. Must be explicit.
          home.pointerCursor.enable = true;

          # Preserve Stylix-managed theme for GTK4 apps.
          # As of home.stateVersion 26.05, gtk.gtk4.theme defaults to null instead
          # of inheriting from config.gtk.theme — explicit assignment is required.
          gtk.gtk4.theme = config.gtk.theme;

          # Enable stylix theming for applications
          stylix.targets = {
            firefox.profileNames = ["default"];
            # Yazi owns no hand-written theme; this target derives theme.toml,
            # including filetype and icon rules, from the active scheme.
            yazi.enable = true;
            # Dank Material Shell is a full-layer shell with its own theme
            # engine; the Stylix target feeds it the preset palette, fonts and
            # opacity instead of leaving it on its upstream default.
            dank-material-shell.enable = (config.wm.shell or "custom") == "dms";
          };

          # GUI environment variables used by the custom stack. Keep them on
          # the same scheme as Stylix so a preset switch does not leave the
          # terminal/desktop split between two palettes.
          theme.gui.colors = {
            background = lib.mkDefault schemeColors.base00;
            foreground = lib.mkDefault schemeColors.base05;
            primary = lib.mkDefault schemeColors.base0D;
            secondary = lib.mkDefault schemeColors.base0E;
            success = lib.mkDefault schemeColors.base0B;
            warning = lib.mkDefault schemeColors.base0A;
            error = lib.mkDefault schemeColors.base08;
          };
        }
      )
    ];

    stylix = let
      inherit (inputs.self.lib) fonts;
      fontPkgs = config.modules.system.stylix-catppuccin.fontPackages;
      cursorPkg = config.modules.system.stylix-catppuccin.cursorPackage;
    in {
      enable = true;
      # Disable release check — Stylix tracks nixos-unstable, not a fixed release
      enableReleaseChecks = false;
      # Disable all auto-targets globally; enable required targets explicitly below.
      # This avoids loading Stylix kmscon defaults that rely on removed nixpkgs options.
      autoEnable = false;

      # Wallpaper source for Stylix wallpaper targets (e.g. noctalia). Mirrors
      # the wallpapers module default (solar-system) so a shell that owns the
      # wallpaper does not receive a null path. The palette is set explicitly
      # via the selected scheme; the runtime wallpaper engine owns the actual
      # selection, so this image is only the build-time seed.
      image = ../home/wallpapers/solar-system.jpg;

      # Every bundled scheme is dark. Stylix defaults polarity to "either";
      # pin it so dark-only targets (e.g. noctalia's theme mode) do not
      # resolve to light.
      polarity = "dark";

      # Base16 palette from the selected preset.
      base16Scheme = schemeColors;

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
        inherit (fonts.cursor) name size;
      };

      # Enable targets for GUI apps
      targets = {
        # Console/TTY theming
        console.enable = true;

        # GUI applications
        gtk.enable = true;

        # Disable all Qt theming since we manage it manually via qt5ct/qt6ct
        qt.enable = false;

        # Disabled: Stylix kmscon target uses removed nixpkgs API (extraConfig, fonts)
        kmscon.enable = false;
      };
    };
  };
}
