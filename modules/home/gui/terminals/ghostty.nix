{
  programs.ghostty = {
    enable = true;

    settings = {
      # Font configuration
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;
      # font-feature = [
      #   "-calt" # Disable ligatures for better readability
      # ];

      # Theme and colors
      theme = "catppuccin-macchiato";
      background-opacity = 0.75; # More transparent for better blur effect
      background-blur-radius = 20; # Add blur effect (requires compositor support)

      # Window configuration
      window-decoration = false; # Keep minimal - no decorations
      gtk-titlebar = false; # No titlebar for minimal look
      window-padding-x = 8;
      window-padding-y = 8;

      # Terminal behavior
      scrollback-limit = 100000; # 100k lines - maximum feasible for performance
      copy-on-select = true;
      confirm-close-surface = false;

      # Cursor configuration
      cursor-style = "block";
      cursor-style-blink = false;

      # Shell integration - auto-detect from running shell
      # Bash will auto-exec into fish via bashrc
      shell-integration-features = "cursor,sudo,title";

      # Performance
      resize-overlay = "never";
      resize-overlay-position = "center";

      # Key bindings
      keybind = [
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+plus=increase_font_size:1"
        "ctrl+shift+minus=decrease_font_size:1"
        "ctrl+shift+zero=reset_font_size"
      ];
    };
  };
}
