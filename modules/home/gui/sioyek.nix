{
  programs = {
    sioyek = {
      enable = true;
      # bindings = {
      #   "move_up" = "k";
      #   "move_down" = "j";
      #   "move_left" = "h";
      #   "move_right" = "l";
      #   "screen_down" = [ "d" "" ];
      #   "screen_up" = [ "u" "" ];
      # };
    };
  };

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = ["sioyek.desktop"];
      };
    };
  };
}
