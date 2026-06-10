{
  config,
  lib,
  ...
}: {
  options.theme.gui = {
    enable = lib.mkEnableOption "GUI-specific theming";

    variant = lib.mkOption {
      type = lib.types.enum ["dark" "light"];
      default = "dark";
      description = "Theme variant for GUI applications";
    };

    colors = {
      # Base colors for GUI applications
      background = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#1e1e2e"
          else "#eff1f5";
        description = "Primary background color for GUI";
      };

      foreground = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#cdd6f4"
          else "#4c4f69";
        description = "Primary foreground/text color for GUI";
      };

      # Accent colors for GUI applications
      primary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#89b4fa"
          else "#1e66f5";
        description = "Primary accent color for GUI";
      };

      secondary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#cba6f7"
          else "#8839ef";
        description = "Secondary accent color for GUI";
      };

      success = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#a6e3a1"
          else "#40a02b";
        description = "Success/positive color for GUI";
      };

      warning = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#f9e2af"
          else "#df8e1d";
        description = "Warning color for GUI";
      };

      error = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#f38ba8"
          else "#d20f39";
        description = "Error/danger color for GUI";
      };

      # Surface colors for GUI elements
      surface0 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#313244"
          else "#e6e9ef";
        description = "Surface level 0 for GUI";
      };

      surface1 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#45475a"
          else "#dce0e8";
        description = "Surface level 1 for GUI";
      };

      surface2 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.gui.variant == "dark"
          then "#585b70"
          else "#bcc0cc";
        description = "Surface level 2 for GUI";
      };
    };

    fonts = {
      mono = lib.mkOption {
        type = lib.types.str;
        default = "JetBrains Mono";
        description = "Monospace font family for GUI applications";
      };

      sans = lib.mkOption {
        type = lib.types.str;
        default = "Inter";
        description = "Sans-serif font family for GUI applications";
      };

      serif = lib.mkOption {
        type = lib.types.str;
        default = "Merriweather";
        description = "Serif font family for GUI applications";
      };
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = "${../wallpapers/the-whale.jpg}";
      description = "Default wallpaper path for GUI environments";
    };
  };

  config = lib.mkIf config.theme.gui.enable {
    # Export GUI theme variables for desktop applications
    home.sessionVariables = {
      GUI_THEME_BACKGROUND = config.theme.gui.colors.background;
      GUI_THEME_FOREGROUND = config.theme.gui.colors.foreground;
      GUI_THEME_PRIMARY = config.theme.gui.colors.primary;
      GUI_THEME_SECONDARY = config.theme.gui.colors.secondary;
      GUI_THEME_SUCCESS = config.theme.gui.colors.success;
      GUI_THEME_WARNING = config.theme.gui.colors.warning;
      GUI_THEME_ERROR = config.theme.gui.colors.error;
    };
  };
}
