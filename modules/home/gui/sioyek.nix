{lib, ...}: {
  programs = {
    sioyek = {
      enable = true;
      # Override stylix's string default with a list to satisfy the apply function
      config.startup_commands = lib.mkForce ["toggle_custom_color"];
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
