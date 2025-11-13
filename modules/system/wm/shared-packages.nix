# Shared system packages for Wayland window managers
# Common packages used by both Hyprland and Niri
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Core Wayland infrastructure
    wayland
    wayland-protocols
    wayland-utils

    # Clipboard management
    wl-clipboard # Wayland clipboard utilities
    wl-clip-persist # Persistent clipboard for Wayland
    cliphist # Clipboard history manager

    # File managers and XDG utilities
    xdg-utils # Desktop integration tools

    # System monitoring and control
    brightnessctl # Screen brightness control
    playerctl # Media player control
    pavucontrol # PulseAudio volume control GUI

    # Screenshot and screen capture tools
    grim # Screenshot utility for Wayland
    slurp # Screen area selection tool
    swappy # Screenshot editing tool

    # Development and scripting utilities
    jq # JSON processor for scripting
    socat # Socket communication for IPC

    # Qt/Theme support for better app integration
    libsForQt5.qt5.qtwayland # Qt5 Wayland platform plugin
    qt6.qtwayland # Qt6 Wayland platform plugin
  ];
}
