{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "surface"
    ++ [
      # Disko config available at ./surface/disko.nix
      # Only used during installation, not imported for running systems
      ./surface/hardware/hardware-configuration.nix
    ];
}
