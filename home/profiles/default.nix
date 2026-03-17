{inputs, ...}: let
  lib = import ../../lib/default.nix {
    inherit (inputs.nixpkgs) lib;
    inherit inputs;
  };

  hosts = ["desktop" "surface" "portable" "hp-probook-wsl" "hp-probook-vmware"];
  homeImports = lib.mkProfileImports hosts;
in {
  _module.args = {inherit homeImports;};
}
