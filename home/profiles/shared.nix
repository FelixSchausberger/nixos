{
  hostConfig ? {},
  lib,
  ...
}: let
  # Use hostConfig as single source of truth for WM selection.
  # Falls back to TUI-only imports for hosts without configured WMs.
  wms = hostConfig.wms or [];
  wmModules = map (wm: ../../modules/home/wm + "/${wm}/default.nix") wms;

  # The full GUI application suite (editors, media apps, ...) belongs to a
  # managed desktop session. An on-demand session host imports only the pieces
  # its session needs (browser, terminal) from its own profile, so it does not
  # grow a full desktop app set on a headless server.
  managedDesktop = (hostConfig.isGui or false) && (hostConfig.autoStartSession or true);
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ wmModules
    ++ lib.optional managedDesktop ../../modules/home/gui;
}
