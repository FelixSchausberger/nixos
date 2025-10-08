sessionTarget: {
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.wm.shared.theme;

    # Color schemes
    colors = {
      catppuccin-macchiato = {
        active_border = "rgb(89b4fa) rgb(cba6f7) 45deg";
        inactive_border = "rgb(45475a)";
        group_active = "rgb(cba6f7)";
        group_inactive = "rgb(45475a)";
        group_locked_active = "rgb(f38ba8)";
        group_locked_inactive = "rgb(45475a)";
        shadow = "rgba(1e1e2eee)";
      };

      custom = {
        active_border = "rgb(89b4fa)";
        inactive_border = "rgb(45475a)";
        group_active = "rgb(cba6f7)";
        group_inactive = "rgb(45475a)";
        group_locked_active = "rgb(f38ba8)";
        group_locked_inactive = "rgb(45475a)";
        shadow = "rgba(1e1e2eee)";
      };
    };

    currentColors = colors.${cfg.colorScheme};
  in
    lib.mkIf cfg.enable {
      # Hyprland-specific theming
      wayland.windowManager.hyprland.settings = lib.mkIf (lib.hasInfix "hyprland" sessionTarget) {
        # General appearance
        general = {
          gaps_in = cfg.gaps.inner;
          gaps_out = cfg.gaps.outer;
          border_size = 2;
          "col.active_border" = currentColors.active_border;
          "col.inactive_border" = currentColors.inactive_border;
          resize_on_border = true;
          extend_border_grab_area = 15;
        };

        # Window decoration
        decoration = {
          rounding = cfg.borderRadius;

          blur = lib.mkIf cfg.blur.enabled {
            inherit (cfg.blur) size passes;
            enabled = true;
            new_optimizations = true;
            ignore_opacity = true;
            noise = 0.1;
            contrast = 1.1;
            brightness = 1.2;
            xray = false;
          };

          shadow = lib.mkIf cfg.shadows.enabled {
            inherit (cfg.shadows) range;
            enabled = true;
            render_power = 3;
            ignore_window = true;
            color = currentColors.shadow;
            offset = "0 8";
            scale = 1.0;
          };

          dim_inactive = false;
          dim_strength = 0.1;
        };

        # Group theming
        group = {
          "col.border_active" = currentColors.group_active;
          "col.border_inactive" = currentColors.group_inactive;
          "col.border_locked_active" = currentColors.group_locked_active;
          "col.border_locked_inactive" = currentColors.group_locked_inactive;
        };
      };

      # GTK theme configuration for consistent theming
      xdg.configFile = {
        "gtk-3.0/settings.ini".text = ''
          [Settings]
          gtk-application-prefer-dark-theme=1
          gtk-theme-name=Adwaita-dark
          gtk-icon-theme-name=Adwaita
          gtk-font-name=Inter 11
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=24
          gtk-toolbar-style=GTK_TOOLBAR_BOTH
          gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
          gtk-button-images=1
          gtk-menu-images=1
          gtk-enable-event-sounds=1
          gtk-enable-input-feedback-sounds=1
          gtk-xft-antialias=1
          gtk-xft-hinting=1
          gtk-xft-hintstyle=hintfull
        '';

        "gtk-4.0/settings.ini".text = ''
          [Settings]
          gtk-application-prefer-dark-theme=1
          gtk-theme-name=Adwaita-dark
          gtk-icon-theme-name=Adwaita
          gtk-font-name=Inter 11
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=24
        '';
      };
    };
}
