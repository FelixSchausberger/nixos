{
  hostName ? "",
  lib,
  inputs,
  ...
}: let
  # Get WM modules for current host from centralized host configuration
  wms = inputs.self.lib.hostData.${hostName}.wms or [];
  wmModules = map (wm: ../../modules/home/wm + "/${wm}/default.nix") wms;
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ (lib.optionals (wms != []) [../../modules/home/gui])
    ++ wmModules;

  # Enable OpenCode on hp-probook-wsl
  ai-assistants.opencode.enable = lib.mkDefault (hostName == "hp-probook-wsl");
}
