{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "hp-probook-wsl"
    ++ [
      ./hp-probook-wsl/hardware/hardware-configuration.nix
    ];
}
