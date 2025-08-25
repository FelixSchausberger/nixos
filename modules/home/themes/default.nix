{
  config,
  lib,
  ...
}: {
  options.theme = {
    enable = lib.mkEnableOption "centralized theming system";

    variant = lib.mkOption {
      type = lib.types.enum ["dark" "light"];
      default = "dark";
      description = "Theme variant";
    };

    colors = {
      # Base colors
      background = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#1e1e2e"
          else "#eff1f5";
        description = "Primary background color";
      };

      foreground = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#cdd6f4"
          else "#4c4f69";
        description = "Primary foreground/text color";
      };

      # Accent colors
      primary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#89b4fa"
          else "#1e66f5";
        description = "Primary accent color";
      };

      secondary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#cba6f7"
          else "#8839ef";
        description = "Secondary accent color";
      };

      success = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#a6e3a1"
          else "#40a02b";
        description = "Success/positive color";
      };

      warning = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#f9e2af"
          else "#df8e1d";
        description = "Warning color";
      };

      error = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#f38ba8"
          else "#d20f39";
        description = "Error/danger color";
      };

      # Surface colors
      surface0 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#313244"
          else "#e6e9ef";
        description = "Surface level 0";
      };

      surface1 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#45475a"
          else "#dce0e8";
        description = "Surface level 1";
      };

      surface2 = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.variant == "dark"
          then "#585b70"
          else "#bcc0cc";
        description = "Surface level 2";
      };
    };

    fonts = {
      mono = lib.mkOption {
        type = lib.types.str;
        default = "JetBrains Mono";
        description = "Monospace font family";
      };

      sans = lib.mkOption {
        type = lib.types.str;
        default = "Inter";
        description = "Sans-serif font family";
      };

      serif = lib.mkOption {
        type = lib.types.str;
        default = "Merriweather";
        description = "Serif font family";
      };
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = "${../wallpapers/the-whale.jpg}";
      description = "Default wallpaper path";
    };
  };

  config = lib.mkIf config.theme.enable {
    # Export theme variables for other modules to use
    home.sessionVariables = {
      THEME_BACKGROUND = config.theme.colors.background;
      THEME_FOREGROUND = config.theme.colors.foreground;
      THEME_PRIMARY = config.theme.colors.primary;
      THEME_SECONDARY = config.theme.colors.secondary;
      THEME_SUCCESS = config.theme.colors.success;
      THEME_WARNING = config.theme.colors.warning;
      THEME_ERROR = config.theme.colors.error;
    };
  };
}
