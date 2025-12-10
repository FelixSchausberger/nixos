# Centralized Catppuccin color scheme definitions
# This file serves as the single source of truth for all Catppuccin color values
# Used across TUI, GUI, and window manager themes
{lib}: let
  colorLib = import ../../../lib/colors {inherit lib;};
in rec {
  # Catppuccin Mocha (Dark variant) - Raw color values (without #)
  mochaRaw = {
    # Base colors
    background = "1e1e2e";
    foreground = "cdd6f4";

    # Accent colors
    primary = "89b4fa"; # Blue
    secondary = "cba6f7"; # Mauve
    success = "a6e3a1"; # Green
    warning = "f9e2af"; # Yellow
    error = "f38ba8"; # Red

    # Surface colors (for layering)
    surface0 = "313244";
    surface1 = "45475a";
    surface2 = "585b70";

    # Extended palette (for advanced theming)
    rosewater = "f5e0dc";
    flamingo = "f2cdcd";
    pink = "f5c2e7";
    mauve = "cba6f7";
    red = "f38ba8";
    maroon = "eba0ac";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    sky = "89dceb";
    sapphire = "74c7ec";
    blue = "89b4fa";
    lavender = "b4befe";
    text = "cdd6f4";
    subtext1 = "bac2de";
    subtext0 = "a6adc8";
    overlay2 = "9399b2";
    overlay1 = "7f849c";
    overlay0 = "6c7086";
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
  };

  # Catppuccin Mocha with # prefix (backward compatibility)
  mocha = colorLib.xcolors mochaRaw;

  # Mocha color variants (hex, rgba with different opacities)
  mochaVariants = colorLib.colorVariants mochaRaw;

  # Catppuccin Latte (Light variant) - Raw color values (without #)
  latteRaw = {
    # Base colors
    background = "eff1f5";
    foreground = "4c4f69";

    # Accent colors
    primary = "1e66f5"; # Blue
    secondary = "8839ef"; # Mauve
    success = "40a02b"; # Green
    warning = "df8e1d"; # Yellow
    error = "d20f39"; # Red

    # Surface colors (for layering)
    surface0 = "e6e9ef";
    surface1 = "dce0e8";
    surface2 = "bcc0cc";

    # Extended palette (for advanced theming)
    rosewater = "dc8a78";
    flamingo = "dd7878";
    pink = "ea76cb";
    mauve = "8839ef";
    red = "d20f39";
    maroon = "e64553";
    peach = "fe640b";
    yellow = "df8e1d";
    green = "40a02b";
    teal = "179299";
    sky = "04a5e5";
    sapphire = "209fb5";
    blue = "1e66f5";
    lavender = "7287fd";
    text = "4c4f69";
    subtext1 = "5c5f77";
    subtext0 = "6c6f85";
    overlay2 = "7c7f93";
    overlay1 = "8c8fa1";
    overlay0 = "9ca0b0";
    base = "eff1f5";
    mantle = "e6e9ef";
    crust = "dce0e8";
  };

  # Catppuccin Latte with # prefix (backward compatibility)
  latte = colorLib.xcolors latteRaw;

  # Latte color variants (hex, rgba with different opacities)
  latteVariants = colorLib.colorVariants latteRaw;

  # Helper function to get colors by variant name
  getColors = variant:
    if variant == "dark"
    then mocha
    else if variant == "light"
    then latte
    else mocha; # Default to dark
}
