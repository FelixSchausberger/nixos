{
  hostConfig ? {},
  lib,
  ...
}: let
  # Use hostConfig as single source of truth for WM selection.
  # Falls back to TUI-only imports for hosts without configured WMs.
  wms = hostConfig.wms or [];
  wmModules = map (wm: ../../modules/home/wm + "/${wm}/default.nix") wms;
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ wmModules
    ++ lib.optional (wms != []) ../../modules/home/gui;
}
