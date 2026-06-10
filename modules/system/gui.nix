# System modules for GUI hosts (desktop, portable, etc.)
{
  imports = [
    # Import TUI base modules first
    ./tui.nix

    # Add GUI-specific modules
    ./display-manager.nix
  ];

  # xdg-desktop-portal configuration is handled by individual window manager modules
  # (hyprland.nix, cosmic.nix, etc.) to ensure proper portal backend selection
}
