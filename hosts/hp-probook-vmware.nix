{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "hp-probook-vmware"
    ++ [
      ./hp-probook-vmware/hardware/hardware-configuration.nix
    ];
}
