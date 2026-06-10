# Flake entrypoint for the m920q homelab/media host.
{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports = importLib.importHost "m920q";
}
