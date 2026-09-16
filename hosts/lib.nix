# Host helper library for resolving configured window managers into module imports.
let
  availableWMs = {
    hyprland = ../modules/system/wm/hyprland.nix;
    gnome = ../modules/system/wm/gnome.nix;
    cosmic = ../modules/system/wm/cosmic.nix;
    niri = ../modules/system/wm/niri.nix;
  };
in {
  # Generate WM module imports from a list of window manager names.
  wmModules = wms:
    map (
      wm:
        if builtins.hasAttr wm availableWMs
        then availableWMs.${wm}
        else builtins.throw "Unknown window manager: ${wm}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames availableWMs)}"
    )
    wms;
}
