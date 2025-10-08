{
  config,
  lib,
  ...
}: {
  options.theme.tui = {
    enable = lib.mkEnableOption "TUI-specific theming";

    variant = lib.mkOption {
      type = lib.types.enum ["dark" "light"];
      default = "dark";
      description = "Theme variant for TUI applications";
    };

    colors = {
      # Base colors for terminal applications
      background = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#1e1e2e"
          else "#eff1f5";
        description = "Primary background color for TUI";
      };

      foreground = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#cdd6f4"
          else "#4c4f69";
        description = "Primary foreground/text color for TUI";
      };

      # Accent colors for TUI applications
      primary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#89b4fa"
          else "#1e66f5";
        description = "Primary accent color for TUI";
      };

      secondary = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#cba6f7"
          else "#8839ef";
        description = "Secondary accent color for TUI";
      };

      success = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#a6e3a1"
          else "#40a02b";
        description = "Success/positive color for TUI";
      };

      warning = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#f9e2af"
          else "#df8e1d";
        description = "Warning color for TUI";
      };

      error = lib.mkOption {
        type = lib.types.str;
        default =
          if config.theme.tui.variant == "dark"
          then "#f38ba8"
          else "#d20f39";
        description = "Error/danger color for TUI";
      };
    };

    fonts = {
      mono = lib.mkOption {
        type = lib.types.str;
        default = "JetBrains Mono";
        description = "Monospace font family for terminals";
      };
    };
  };

  config = lib.mkIf config.theme.tui.enable {
    # Export TUI theme variables for terminal applications
    home.sessionVariables = {
      TUI_THEME_BACKGROUND = config.theme.tui.colors.background;
      TUI_THEME_FOREGROUND = config.theme.tui.colors.foreground;
      TUI_THEME_PRIMARY = config.theme.tui.colors.primary;
      TUI_THEME_SECONDARY = config.theme.tui.colors.secondary;
      TUI_THEME_SUCCESS = config.theme.tui.colors.success;
      TUI_THEME_WARNING = config.theme.tui.colors.warning;
      TUI_THEME_ERROR = config.theme.tui.colors.error;
    };
  };
}
