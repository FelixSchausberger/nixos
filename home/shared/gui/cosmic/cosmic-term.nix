{
  # cosmicLib,
  config,
  ...
}: {
  programs.cosmic-term = {
    enable = true;
    profiles = [
      {
        command = "fish";
        hold = false;
        is_default = true;
        name = "Default";
        syntax_theme_dark = "COSMIC Dark";
        syntax_theme_light = "COSMIC Light";
        tab_title = "Default";
        working_directory = "/home/${config.home.username}";
      }
    ];

    settings = {
      # app_theme = cosmicLib.cosmic.mkRON "enum" "Dark";
      # bold_font_weight = 700;
      # dim_font_weight = 300;
      # focus_follows_mouse = true;
      font_name = "FiraCode Mono";
      font_size = 20;
      # font_size_zoom_step_mul_100 = 100;
      # font_stretch = 100;
      # font_weight = 400;
      opacity = 80;
      show_headerbar = false;
      use_bright_bold = true;
    };
  };
}
