{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "surface"
    ++ [
      ./surface/hardware/hardware-configuration.nix
    ];
}
