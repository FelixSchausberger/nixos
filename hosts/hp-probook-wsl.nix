{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "hp-probook-wsl"
    ++ [
      # Disko config available at ./hp-probook-wsl/disko/disko.nix
      # Only used during installation, not imported for running systems
      ./hp-probook-wsl/hardware/hardware-configuration.nix
    ];
}
