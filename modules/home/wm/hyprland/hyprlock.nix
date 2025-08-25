{config, ...}: {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 300;
        hide_cursor = false;
        no_fade_in = false;
        no_fade_out = false;
        ignore_empty_input = false;
        immediate_render = false;
        pam_module = "hyprlock";
      };

      background = [
        {
          monitor = "eDP-1";
          path = config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg";
          blur_passes = 3;
          blur_size = 8;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "250, 60";
          outline_thickness = 2;
          dots_size = 0.33;
          dots_spacing = 0.15;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgb(89b4fa)";
          inner_color = "rgb(1e1e2e)";
          font_color = "rgb(cdd6f4)";
          fade_on_empty = true;
          fade_timeout = 1000;
          placeholder_text = "<i>Password...</i>";
          hide_input = false;
          rounding = 12;
          check_color = "rgb(a6e3a1)";
          fail_color = "rgb(f38ba8)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300;
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1;
          invert_numlock = false;
          swap_font_color = false;
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(cdd6f4)";
          font_size = 90;
          font_family = "JetBrainsMono Nerd Font ExtraBold";
          position = "0, 80";
          halign = "center";
          valign = "center";
          shadow_passes = 5;
          shadow_size = 10;
        }
        {
          monitor = "";
          text = "Hi there, $USER";
          color = "rgb(cdd6f4)";
          font_size = 20;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 0";
          halign = "center";
          valign = "center";
          shadow_passes = 5;
          shadow_size = 10;
        }
      ];
    };
  };
}
