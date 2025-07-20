{inputs, ...}: let
  lib = import ../../lib/default.nix {
    lib = inputs.nixpkgs.lib;
    inherit inputs;
  };

  hosts = ["desktop" "surface" "pdemu1cml000312" "portable"];
  homeImports = lib.mkProfileImports hosts;

  extraSpecialArgs = {inherit inputs;};
  inherit (inputs.home-manager.lib) homeManagerConfiguration;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  # We need to pass this to NixOS' HM module
  _module.args = {inherit homeImports;};

  flake = {
    homeConfigurations = let
      mkHomeConfig = host: {
        name = "schausberger_${host}";
        value = homeManagerConfiguration {
          modules = homeImports."${lib.getUserHost "schausberger" host}";
          inherit pkgs extraSpecialArgs;
        };
      };
    in
      inputs.nixpkgs.lib.listToAttrs (map mkHomeConfig hosts);
  };
}
