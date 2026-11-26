{config, ...}: {
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
      font_name = "FiraCode Mono";
      font_size = 20;
      opacity = 80;
      show_headerbar = false;
      use_bright_bold = true;
    };
  };
}
