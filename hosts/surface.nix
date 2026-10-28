{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "surface"
    ++ [
      # importHost pulls every module in ./surface/ (default.nix, disko.nix):
      # disko.nix both defines the running ZFS fileSystems and carries the
      # diskoScript used by nixos-anywhere / install-remote.
      ./surface/hardware/hardware-configuration.nix
    ];
}
