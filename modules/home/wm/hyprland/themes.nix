{
  config,
  lib,
  inputs,
  ...
}: let
  catppuccin = inputs.self.lib.catppuccinColors.mocha;
in {
  imports = [
    ../shared/gtk-config.nix
  ];
  # Aesthetic options (borderRadius, gaps, blur, shadows) centralized in wm.shared.theme
  # This module only defines Hyprland-specific enable option
  options.wm.hyprland.theme = {
    enable = lib.mkEnableOption "Hyprland theme configuration" // {default = true;};
  };

  config = let
    cfg = config.wm.hyprland.theme;
    sharedTheme = config.wm.shared.theme;

    # Color schemes using centralized Catppuccin definitions
    colors = {
      catppuccin-macchiato = {
        active_border = "rgb(${catppuccin.blue}) rgb(${catppuccin.mauve}) 45deg";
        inactive_border = "rgb(${catppuccin.surface1})";
        group_active = "rgb(${catppuccin.mauve})";
        group_inactive = "rgb(${catppuccin.surface1})";
        group_locked_active = "rgb(${catppuccin.red})";
        group_locked_inactive = "rgb(${catppuccin.surface1})";
        shadow = "rgba(${catppuccin.base}ee)";
      };

      custom = {
        active_border = "rgb(${catppuccin.blue})";
        inactive_border = "rgb(${catppuccin.surface1})";
        group_active = "rgb(${catppuccin.mauve})";
        group_inactive = "rgb(${catppuccin.surface1})";
        group_locked_active = "rgb(${catppuccin.red})";
        group_locked_inactive = "rgb(${catppuccin.surface1})";
        shadow = "rgba(${catppuccin.base}ee)";
      };
    };

    currentColors = colors.${sharedTheme.colorScheme};
  in
    lib.mkIf (config.wm.hyprland.enable && cfg.enable) {
      wayland.windowManager.hyprland.settings = {
        # General appearance using centralized shared theme
        general = {
          gaps_in = sharedTheme.gaps.inner;
          gaps_out = sharedTheme.gaps.outer;
          border_size = 2;
          "col.active_border" = currentColors.active_border;
          "col.inactive_border" = currentColors.inactive_border;
          resize_on_border = true;
          extend_border_grab_area = 15;
        };

        # Window decoration using centralized shared theme
        decoration = {
          rounding = sharedTheme.borderRadius;

          blur = lib.mkIf sharedTheme.blur.enabled {
            inherit (sharedTheme.blur) size;
            inherit (sharedTheme.blur) passes;
            enabled = true;
            new_optimizations = true;
            ignore_opacity = true;
            noise = 0.1;
            contrast = 1.1;
            brightness = 1.2;
            xray = false;
          };

          shadow = lib.mkIf sharedTheme.shadows.enabled {
            inherit (sharedTheme.shadows) range;
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

      # GTK theme configuration handled by gtk-config.nix import
    };
}
