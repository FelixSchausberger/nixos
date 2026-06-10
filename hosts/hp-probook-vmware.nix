# Flake entrypoint for the VMware variant of the HP ProBook host.
# Imports generated VM hardware metadata while treating disko as install-time only.
{lib, ...}: let
  importLib = import ../lib/import.nix {inherit lib;};
in {
  imports =
    importLib.importHost "hp-probook-vmware"
    ++ [
      # Disko config available at ./hp-probook-vmware/disko.nix
      # Only used during installation, not imported for running systems
      ./hp-probook-vmware/hardware/hardware-configuration.nix
    ];
}
