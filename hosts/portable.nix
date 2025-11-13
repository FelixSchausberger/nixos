{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "portable"
    ++ [
      ./portable/hardware/hardware-configuration.nix
    ];
}
