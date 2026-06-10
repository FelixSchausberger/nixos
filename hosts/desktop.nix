# Flake entrypoint for the desktop host.
# Imports host defaults plus generated hardware data, while keeping disko install-only.
{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "desktop"
    ++ [
      # Disko config available at ./desktop/disko.nix
      # Only used during installation, not imported for running systems
      ./desktop/hardware/hardware-configuration.nix
    ];
}
