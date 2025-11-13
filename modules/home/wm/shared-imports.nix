# Shared imports for WM modules
# This module imports homeManager modules that should only be imported once
# to avoid duplicate option declarations when multiple WMs are enabled
{inputs, ...}: {
  imports = [
    inputs.wired.homeManagerModules.default # Wired notification daemon
  ];
}
