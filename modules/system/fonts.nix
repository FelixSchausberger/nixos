{pkgs, ...}: {
  # Centralized fonts configuration for all WMs and desktop environments
  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = true;

    packages = with pkgs; [
      # Icon and symbol fonts
      font-awesome

      # Noto fonts family (comprehensive Unicode coverage)
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans

      # Liberation fonts (metric-compatible with Microsoft fonts)
      liberation_ttf

      # Programming and monospace fonts
      fira-code
      fira-code-symbols
      jetbrains-mono

      # Nerd Fonts variants (patched with icons)
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.meslo-lg
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      cache32Bit = true;
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";

      defaultFonts = {
        serif = ["Noto Serif" "Liberation Serif"];
        sansSerif = ["Noto Sans" "Liberation Sans"];
        monospace = ["JetBrainsMono Nerd Font" "Liberation Mono"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };
}
