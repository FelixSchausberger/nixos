{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "desktop"
    ++ [
      # Disko config available at ./desktop/disko/disko.nix
      # Only used during installation, not imported for running systems
      ./desktop/hardware/hardware-configuration.nix
    ];
}
