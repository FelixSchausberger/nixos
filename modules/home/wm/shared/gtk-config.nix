# Centralized GTK configuration for window managers
# Provides consistent theming across all WMs
{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) fonts;
in {
  options.wm.shared.gtk = {
    enable = lib.mkEnableOption "Shared GTK configuration" // {default = true;};
  };

  config = lib.mkIf config.wm.shared.gtk.enable {
    # GTK 3.0 theme configuration
    xdg.configFile."gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
      gtk-theme-name=Adwaita-dark
      gtk-icon-theme-name=Adwaita
      gtk-font-name=${fonts.families.sansSerif.name} ${toString fonts.sizes.normal}
      gtk-cursor-theme-name=${fonts.cursor.name}
      gtk-cursor-theme-size=${toString fonts.cursor.size}
      gtk-toolbar-style=GTK_TOOLBAR_BOTH
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=1
      gtk-menu-images=1
      gtk-enable-event-sounds=1
      gtk-enable-input-feedback-sounds=1
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=hintfull
    '';

    # GTK 4.0 theme configuration
    xdg.configFile."gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
      gtk-theme-name=Adwaita-dark
      gtk-icon-theme-name=Adwaita
      gtk-font-name=${fonts.families.sansSerif.name} ${toString fonts.sizes.normal}
      gtk-cursor-theme-name=${fonts.cursor.name}
      gtk-cursor-theme-size=${toString fonts.cursor.size}
    '';
  };
}
