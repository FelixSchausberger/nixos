# Shared imports for WM modules
# This module imports homeManager modules that should only be imported once
# to avoid duplicate option declarations when multiple WMs are enabled
{inputs, ...}: {
  imports = [
    inputs.wired.homeManagerModules.default # Wired notification daemon
    ../wallpapers # Wallpaper management module
    ./shared/ala-lape.nix # Idle inhibitor (gamepad/process-based)
    ./shared/graphical-service.nix # Reusable graphical service wrapper
    ./shared/walker.nix # Walker application launcher (shared between WMs)
  ];
}
