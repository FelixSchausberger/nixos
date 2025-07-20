{pkgs, ...}: {
  imports = [
    ../shared.nix
    ../../../modules/home/gui/freecad.nix # General purpose Open Source 3D CAD/MCAD/CAx/CAE/PLM modeler
    ../../../modules/home/gui/steam.nix # A digital distribution platform
  ];

  home.packages = with pkgs; [
    # Gaming and emulation
    linuxKernel.packages.linux_zen.xpadneo # Advanced Linux driver for Xbox One wireless controllers
    lutris # Open Source gaming platform for GNU/Linux
    wineWowPackages.waylandFull # An Open Source implementation of the Windows API on top of X, OpenGL, and Unix

    # System utilities
    libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
    vial # Open-source GUI and QMK fork for configuring your keyboard in real time
  ];

  # # Configure Hyprland for desktop/gaming environment
  # wm.hyprland = {
  #   browser = "firefox";
  #   terminal = "wezterm";
  #   fileManager = "nautilus";
  #   enableGaming = true;
  # };
}
