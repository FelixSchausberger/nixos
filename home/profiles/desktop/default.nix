{pkgs, ...}: {
  imports = [
    ./hyprland.nix
    ./niri.nix
  ];

  # Feature-based configuration for desktop
  features = {
    development = {
      enable = true;
      languages = ["nix" "rust" "python"];
    };

    creative = {
      enable = true;
      tools = ["image" "3d" "video"];
    };

    gaming = {
      enable = true;
      platforms = ["steam" "lutris" "minecraft"];
    };
  };

  home.packages = with pkgs; [
    # Desktop-specific hardware support
    linuxKernel.packages.linux_zen.xpadneo # Advanced Linux driver for Xbox One wireless controllers
    wineWowPackages.waylandFull # An Open Source implementation of the Windows API on top of X, OpenGL, and Unix
    libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
    vial # Open-source GUI and QMK fork for configuring your keyboard in real time
  ];
}
