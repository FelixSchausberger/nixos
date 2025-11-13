sessionTarget: {
  config,
  lib,
  inputs,
  ...
}: let
  catppuccin = inputs.self.lib.catppuccinColors.mocha;
in {
  imports = [
    ./gtk-config.nix
  ];
  config = let
    cfg = config.wm.shared.theme;

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
          "col.active_border" = lib.mkDefault currentColors.active_border;
          "col.inactive_border" = lib.mkDefault currentColors.inactive_border;
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
            color = lib.mkDefault currentColors.shadow;
            offset = "0 8";
            scale = 1.0;
          };

          dim_inactive = false;
          dim_strength = 0.1;
        };

        # Group theming
        group = {
          "col.border_active" = lib.mkDefault currentColors.group_active;
          "col.border_inactive" = lib.mkDefault currentColors.group_inactive;
          "col.border_locked_active" = lib.mkDefault currentColors.group_locked_active;
          "col.border_locked_inactive" = lib.mkDefault currentColors.group_locked_inactive;
        };
      };

      # GTK theme configuration handled by gtk-config.nix import
    };
}
