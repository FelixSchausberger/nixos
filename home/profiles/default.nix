{inputs, ...}: let
  inherit (inputs.self.lib) defaults;
  lib = import ../../lib/default.nix {
    inherit (inputs.nixpkgs) lib;
    # inherit (pkgs) lib;
    inherit inputs;
  };

  hosts = ["desktop" "surface" "portable" "hp-probook-wsl" "hp-probook-vmware"];
  homeImports = lib.mkProfileImports hosts;

  # Extract hostname from configuration name for each host
  mkExtraSpecialArgs = host: {
    inherit inputs;
    hostName = host;
  };
  inherit (inputs.home-manager.lib) homeManagerConfiguration;
in {
  # We need to pass this to NixOS' HM module
  _module.args = {inherit homeImports;};
}
