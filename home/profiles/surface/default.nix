{pkgs, ...}: {
  imports = [];

  home.packages = with pkgs; [
    libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
    tlp # Advanced Power Management for Linux
    vial # Open-source GUI and QMK fork for configuring your keyboard in real time
  ];

  # # Configure for old private laptop
  # wm.hyprland = {
  #   browser = "firefox";
  #   terminal = "ghostty";
  #   fileManager = "cosmic-files";
  #   enableGaming = false;
  # };
}
