{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "portable"
    ++ [
      # Disko config available at ./portable/disko.nix
      # Only used during installation, not imported for running systems
      ./portable/hardware/hardware-configuration.nix
    ];
}
