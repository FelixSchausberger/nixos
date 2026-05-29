# Flake entrypoint for the WSL host profile.
# Includes generated hardware metadata but keeps disko out of runtime imports.
{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "hp-probook-wsl"
    ++ [
      # Disko config available at ./hp-probook-wsl/disko.nix
      # Only used during installation, not imported for running systems
      ./hp-probook-wsl/hardware/hardware-configuration.nix
    ];
}
