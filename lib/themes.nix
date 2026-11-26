# Build-time base16 color schemes for the theme presets.
#
# The runtime wallpaper theme (wallpapers.dynamic.themes) and the build-time
# color scheme are separate choices: switching colors regenerates app configs
# and needs a rebuild, while switching wallpaper families is immediate. Keep
# the names aligned so a preset can name its matching wallpaper family.
{
  catppuccin-mocha = {
    base00 = "#1e1e2e";
    base01 = "#181825";
    base02 = "#313244";
    base03 = "#45475a";
    base04 = "#585b70";
    base05 = "#cdd6f4";
    base06 = "#bac2de";
    base07 = "#a6adc8";
    base08 = "#f38ba8";
    base09 = "#fab387";
    base0A = "#f9e2af";
    base0B = "#a6e3a1";
    base0C = "#94e2d5";
    base0D = "#89b4fa";
    base0E = "#cba6f7";
    base0F = "#f2cdcd";
  };

  # Everforest Dark (hard) palette mapped to the base16 hue roles. The
  # canonical base16 file assigns base08 to blue; the roles here follow the
  # slot semantics (red error, green primary, teal success) so Stylix and the
  # shell targets do not paint errors blue.
  everforest-dark = {
    base00 = "#272e33";
    base01 = "#2e383c";
    base02 = "#414b50";
    base03 = "#859289";
    base04 = "#9da9a0";
    base05 = "#d3c6aa";
    base06 = "#e4e1cd";
    base07 = "#fdf6e3";
    base08 = "#e67e80";
    base09 = "#e69875";
    base0A = "#dbbc7f";
    base0B = "#83c092";
    base0C = "#7fbbb3";
    base0D = "#a7c080";
    base0E = "#d699b6";
    base0F = "#4c3743";
  };

  # Monochrome surfaces with just enough accent color for diffs and errors.
  ascii-mono = {
    base00 = "#000000";
    base01 = "#0b0b0b";
    base02 = "#161616";
    base03 = "#2a2a2a";
    base04 = "#5c5c5c";
    base05 = "#c9c9c9";
    base06 = "#e6e6e6";
    base07 = "#ffffff";
    base08 = "#ff6b6b";
    base09 = "#ffb86c";
    base0A = "#f1fa8c";
    base0B = "#7ee787";
    base0C = "#79c0ff";
    base0D = "#a5d6ff";
    base0E = "#d2a8ff";
    base0F = "#8b949e";
  };
}
