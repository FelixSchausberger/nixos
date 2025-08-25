{pkgs, ...}: {
  # hp-probook-wsl-specific Hyprland configuration
  wm.hyprland = {
    # WSL display configuration - WSLg creates a virtual display
    monitors = ["Virtual-1,1920x1080@60,0x0,1"];

    # Work environment application preferences
    browser = "zen";
    terminal = "ghostty";
    fileManager = "cosmic-files";

    # Work-focused scratchpad preferences
    scratchpad = {
      musicApp = "spotify-player"; # Lightweight for work
      notesApp = "obsidian"; # Full-featured for work notes
    };
  };

  # WSL-specific Hyprland configuration
  wayland.windowManager.hyprland.settings = {
    # WSLg-specific environment variables
    env = [
      # WSLg Wayland optimizations
      "WLR_NO_HARDWARE_CURSORS,1"
      "NIXOS_OZONE_WL,1"
      "QT_QPA_PLATFORM,wayland"
      "GDK_BACKEND,wayland"
      "MOZ_ENABLE_WAYLAND,1"
    ];

    exec-once = [
      # Start work applications as scratchpads
      "[workspace special:teams silent] ${pkgs.teams-for-linux}/bin/teams-for-linux"
    ];

    # WSL-specific window rules
    windowrulev2 = [
      # MS Teams scratchpad - floating window in center
      "float,class:^(teams-for-linux)$"
      "size 80% 75%,class:^(teams-for-linux)$"
      "center,class:^(teams-for-linux)$"
      "rounding 12,class:^(teams-for-linux)$"
      "opacity 0.98,class:^(teams-for-linux)$"

      # Make WSL applications play nice with the virtual display
      "immediate,class:^(firefox|chromium|zen-alpha)$"
    ];

    # WSL-specific workspace configuration
    workspace = [
      "special:teams, gapsout:15, gapsin:8, bordersize:2, border:true, shadow:true"
    ];

    # WSL-specific input configuration
    input = {
      # Handle WSL virtual input devices
      follow_mouse = 1;
      sensitivity = 0; # -1.0 - 1.0, 0 means no modification
    };
  };
}
