# Flake entrypoint for the portable host.
# Imports portable defaults and generated hardware data; disko remains install-time only.
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
