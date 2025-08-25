# Home modules for full GUI hosts (desktop, portable, etc.)
{lib, ...}: {
  imports = [
    # Import TUI base modules first
    ./tui-only.nix

    # Add GUI-specific modules
    ./gui
    ./themes
    ./wallpapers
  ];

  # Enable centralized theming system for GUI hosts
  theme.enable = lib.mkForce true;
}
