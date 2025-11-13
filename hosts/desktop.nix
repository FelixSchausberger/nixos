{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "desktop"
    ++ [
      ./desktop/hardware/hardware-configuration.nix
    ];
}
