{hostConfig, ...}: let
  # Import WM modules based on hostConfig.wm list
  wmModules = map (wm: ../../modules/home/wm + "/${wm}") hostConfig.wm;
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ wmModules;
}
