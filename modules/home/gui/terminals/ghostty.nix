{
  pkgs,
  hostName ? "",
  lib,
  ...
}: let
  # Hosts with real GPUs that support GLSL 4.60 for blur effects
  supportsBlur = builtins.elem hostName ["desktop" "surface"];
in {
  programs.ghostty = {
    enable = true;

    settings =
      {
        # Font configuration
        font-family = "JetBrainsMono Nerd Font";
        font-size = 14;
        # font-feature = [
        #   "-calt" # Disable ligatures for better readability
        # ];

        # Theme and colors - using Stylix integration
        background-opacity =
          if supportsBlur
          then 0.75
          else 0.85;

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

        # Shell configuration
        # Start fish directly to avoid bash->fish transition issues
        command = "${pkgs.fish}/bin/fish";

        # Shell integration
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
          "ctrl+enter=unbind" # Allow Ctrl+Enter to pass through to applications
          "shift+enter=text:\\n" # Send literal newline for Claude Code line breaks
        ];
      }
      // lib.optionalAttrs supportsBlur {
        # Blur effect (requires GLSL 4.60 support, only on real GPUs)
        background-blur-radius = 20;
      };
  };
}
