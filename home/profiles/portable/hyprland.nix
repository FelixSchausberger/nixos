{
  # Portable-specific Hyprland configuration
  wm.hyprland = {
    # Monitor configuration for portable/recovery system
    # Using auto-detection for maximum hardware compatibility
    monitors = [
      ",preferred,auto,1"
    ];

    # Portable-specific application preferences (lightweight)
    browser = "firefox"; # More reliable for recovery scenarios
    terminal = "ghostty"; # Fast terminal
    fileManager = "cosmic-files";

    # Portable-specific scratchpad preferences (lightweight)
    scratchpad = {
      musicApp = "spotify-player"; # Terminal-based, lighter
      notesApp = "basalt"; # Custom lightweight notes app
    };
  };
}
