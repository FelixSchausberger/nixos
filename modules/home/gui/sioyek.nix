{lib, ...}: {
  programs = {
    sioyek = {
      enable = true;
      # Override stylix's string default with a list to satisfy the apply function
      config.startup_commands = lib.mkForce ["toggle_custom_color"];
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
