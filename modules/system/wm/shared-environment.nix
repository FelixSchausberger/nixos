# Shared Wayland environment configuration
# Common environment variables for all Wayland compositors
{
  lib,
  config,
  pkgs,
  hostConfig,
  ...
}: {
  # Common Wayland environment variables that all WMs can share
  environment.sessionVariables = {
    # Wayland
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";

    # Qt (allow Stylix to override QT_QPA_PLATFORMTHEME)
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = lib.mkDefault "qt6ct";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";

    # GTK
    GDK_BACKEND = "wayland,x11";
    GDK_SCALE = "1";

    # Mozilla
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_WEBRENDER = "1";
    MOZ_ACCELERATED = "1";

    # XDG
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };

  # XDG Portal configuration - conditional based on which WM is active
  xdg.portal = {
    enable = true;
    wlr.enable = true;

    config = lib.mkMerge [
      # Hyprland configuration (highest priority)
      (lib.mkIf (builtins.elem "hyprland" hostConfig.wms && config.programs.hyprland.enable) {
        common.default = lib.mkForce ["hyprland" "gtk"];
        hyprland = {
          default = ["hyprland" "gtk"];
          "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
          "org.freedesktop.impl.portal.AppChooser" = ["gtk"];
          "org.freedesktop.impl.portal.Print" = ["gtk"];
          "org.freedesktop.impl.portal.Settings" = ["gtk"];
          "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
          "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
          "org.freedesktop.impl.portal.Inhibit" = ["hyprland"];
        };
      })

      # Niri configuration (medium priority, only if Hyprland is not active)
      (lib.mkIf (builtins.elem "niri" hostConfig.wms && config.programs.niri.enable && !config.programs.hyprland.enable) {
        common.default = ["gnome" "wlr" "gtk"];
        niri = {
          default = ["gnome" "wlr" "gtk"];
          "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
          "org.freedesktop.impl.portal.AppChooser" = ["gtk"];
          "org.freedesktop.impl.portal.Print" = ["gtk"];
          "org.freedesktop.impl.portal.Settings" = ["gnome"];
          "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
          "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
          "org.freedesktop.impl.portal.Inhibit" = ["gnome"];
        };
      })

      # GNOME configuration (lowest priority, only if no other WM is active)
      (lib.mkIf (builtins.elem "gnome" hostConfig.wms && !config.programs.hyprland.enable && !config.programs.niri.enable) {
        common.default = ["gnome" "gtk"];
      })
    ];

    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
  };
}
