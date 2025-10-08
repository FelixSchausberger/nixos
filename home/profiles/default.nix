{inputs, ...}: let
  lib = import ../../lib/default.nix {
    inherit (inputs.nixpkgs) lib;
    inherit inputs;
  };

  hosts = ["desktop" "surface" "portable" "hp-probook-wsl"];
  homeImports = lib.mkProfileImports hosts;

  # Extract hostname from configuration name for each host
  mkExtraSpecialArgs = host: {
    inherit inputs;
    hostName = host;
  };
  inherit (inputs.home-manager.lib) homeManagerConfiguration;
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [inputs.nur.overlays.default];
    config.allowUnfree = true;
  };
in {
  # We need to pass this to NixOS' HM module
  _module.args = {inherit homeImports;};
}
