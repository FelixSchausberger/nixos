# Home modules for full GUI hosts (desktop, portable, etc.)
{lib, ...}: {
  imports = [
    # Import TUI base modules first
    ./tui-only.nix

    # Add GUI-specific modules
    ./gui
    ./wallpapers
  ];

  # Enable both TUI and GUI theming for full GUI hosts
  theme = {
    tui.enable = lib.mkForce true; # Enable TUI themes
    gui.enable = lib.mkForce true; # Enable GUI themes
  };
}
