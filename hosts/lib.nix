{
  # Helper functions for host configurations

  # Generate WM module imports based on a list of window managers
  wmModules = wms: map (wm: ../modules/system/wm + "/${wm}.nix") wms;
}
