# System modules for GUI hosts (desktop, portable, etc.)
{
  imports = [
    # Import TUI base modules first
    ./tui.nix

    # Add GUI-specific modules
    ./display-manager.nix
  ];

  # Configure xdg-desktop-portal for GUI applications
  xdg.portal = {
    enable = true;
    # Use default portal implementation selection for compatibility
    config.common.default = "*";
  };
}
