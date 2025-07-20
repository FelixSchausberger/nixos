{pkgs, ...}: {
  # pdemu1cml000312-specific Hyprland configuration
  wm.hyprland = {
    # Monitor configuration for this specific host - explicit native resolution
    monitors = ["eDP-1,1920x1200@60,0x0,1" "DP-2,2560x1440@60,1920x0,1"];

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

  # Host-specific startup applications
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # Start MS Teams as scratchpad for work
      "[workspace special:teams silent] ${pkgs.teams-for-linux}/bin/teams-for-linux"
    ];

    # Host-specific window rules for MS Teams scratchpad
    windowrulev2 = [
      # MS Teams scratchpad - floating window in center
      "float,class:^(teams-for-linux)$"
      "size 80% 75%,class:^(teams-for-linux)$"
      "center,class:^(teams-for-linux)$"
      "rounding 12,class:^(teams-for-linux)$"
      "opacity 0.98,class:^(teams-for-linux)$"
    ];

    # Host-specific workspace rules for MS Teams scratchpad
    workspace = [
      "special:teams, gapsout:15, gapsin:8, bordersize:2, border:true, shadow:true"
    ];
  };
}
