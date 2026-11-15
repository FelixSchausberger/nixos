{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;

    settings = {
      # Font configuration
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;
      # font-feature = [
      #   "-calt" # Disable ligatures for better readability
      # ];

      # Theme and colors — stylix provides theme = stylix via its HM integration
      # Transparency lets the compositor (Niri/Hyprland) blur apply.
      # Ghostty's own background-blur is KDE/macOS-only, so it stays unset.
      background-opacity = 0.75;

      # Window configuration
      window-decoration = false; # Keep minimal - no decorations
      gtk-titlebar = false; # No titlebar for minimal look
      window-padding-x = 16;
      window-padding-y = 16;
      window-padding-color = "extend"; # Extend bg color into padding in alt-screen

      # Terminal behavior
      # 100k lines; the default 50 MB scrollback-limit-bytes still caps
      # memory when the history is dense.
      scrollback-limit-lines = 100000;
      copy-on-select = "primary";
      confirm-close-surface = false;

      # Cursor configuration
      cursor-style = "block";
      cursor-style-blink = false;

      # Launch fish explicitly; system login shell remains bash (NixOS default).
      # fish is not POSIX-compatible, so setting it as login shell can break
      # systemd units and other system scripts that depend on shell=bash.
      command = "${pkgs.fish}/bin/fish";

      # Shell integration
      shell-integration = "fish";
      # ssh-env forwards COLORTERM/TERM_PROGRAM/TERM_PROGRAM_VERSION;
      # ssh-terminfo installs xterm-ghostty on hosts that ship tic.
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";

      # Performance
      resize-overlay = "never";

      # Key bindings
      keybind = [
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+plus=increase_font_size:1"
        "ctrl+shift+minus=decrease_font_size:1"
        "ctrl+shift+zero=reset_font_size"
        # Ghostty defaults ctrl+enter to toggle_fullscreen, which steals the
        # key from TUI apps (opencode uses ctrl+enter for line breaks).
        # Unbind it so the keypress reaches the PTY instead.
        "ctrl+enter=unbind"
      ];
    };
  };
}
