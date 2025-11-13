# Centralized font configuration for the entire NixOS configuration
# This file defines font families, sizes, and package references used across the system
{
  # Font families
  families = {
    # Monospace font for terminals, editors, and code
    monospace = {
      name = "JetBrainsMono Nerd Font Mono";
      package = "nerdfonts";
      # For nerdfonts overlay: override with fonts = [ "JetBrainsMono" ]
    };

    # Sans-serif font for UI elements
    sansSerif = {
      name = "Inter";
      package = "inter";
    };

    # Serif font for documents and reading
    serif = {
      name = "Merriweather";
      package = "merriweather";
    };
  };

  # Cursor theme configuration
  cursor = {
    name = "Bibata-Modern-Classic";
    package = "bibata-cursors";
    size = 24;
  };

  # Default font sizes (in points)
  sizes = {
    small = 10;
    normal = 11;
    large = 12;
    huge = 14;
  };

  # GTK-specific font configuration
  gtk = {
    fontName = "Inter 11";
  };
}
