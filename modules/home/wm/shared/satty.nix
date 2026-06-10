{pkgs, ...}: {
  config = {
    home = {
      packages = with pkgs; [
        satty # Modern screenshot annotation tool
        wayshot # Modern Rust-based screenshot tool for Wayland
        slurp # Required for region selection
      ];

      # Create screenshot scripts and ensure screenshots directory exists
      file = {
        ".local/bin/screenshot-region" = {
          text = ''
            #!/bin/bash
            # Take region screenshot with satty
            wayshot -s "$(slurp)" --stdout | satty --filename - --output-filename ~/Pictures/Screenshots/$(date '+%Y%m%d-%H%M%S').png
          '';
          executable = true;
        };

        ".local/bin/screenshot-full" = {
          text = ''
            #!/bin/bash
            # Take full screen screenshot with satty
            wayshot --stdout | satty --filename - --fullscreen --output-filename ~/Pictures/Screenshots/$(date '+%Y%m%d-%H%M%S').png
          '';
          executable = true;
        };

        "Pictures/Screenshots/.keep".text = "";
      };

      # Ensure scripts are in PATH
      sessionPath = ["$HOME/.local/bin"];
    };
  };
}
