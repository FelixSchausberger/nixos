let
  # Available window manager modules
  availableWMs = {
    hyprland = ../modules/system/wm/hyprland.nix;
    gnome = ../modules/system/wm/gnome.nix;
    cosmic = ../modules/system/wm/cosmic.nix;
    niri = ../modules/system/wm/niri.nix;
  };
in {
  # Helper functions for host configurations

  # Generate WM module imports based on window manager selection
  # Usage: wmModules ["hyprland" "gnome"] or wmModules { hyprland.enable = true; }
  wmModules = wms:
    if builtins.isList wms
    then
      # Legacy list format: ["hyprland" "gnome"]
      map (
        wm:
          if builtins.hasAttr wm availableWMs
          then availableWMs.${wm}
          else builtins.throw "Unknown window manager: ${wm}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames availableWMs)}"
      )
      wms
    else
      # Attribute set format: { hyprland.enable = true; gnome.enable = false; }
      builtins.concatLists (builtins.attrValues (builtins.mapAttrs (
          name: config:
            if config.enable or false
            then
              if builtins.hasAttr name availableWMs
              then [availableWMs.${name}]
              else builtins.throw "Unknown window manager: ${name}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames availableWMs)}"
            else []
        )
        wms));

  # Convenience function to check if a specific WM is enabled
  hasWM = wms: wm:
    if builtins.isList wms
    then builtins.elem wm wms
    else wms.${wm}.enable or false;

  # Get list of enabled WMs regardless of input format
  enabledWMs = wms:
    if builtins.isList wms
    then wms
    else builtins.filter (wm: wms.${wm}.enable or false) (builtins.attrNames wms);
}
