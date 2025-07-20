{inputs, ...}: let
  lib = import ../../lib/default.nix {
    inherit (inputs.nixpkgs) lib;
    inherit inputs;
  };

  hosts = ["desktop" "surface" "pdemu1cml000312" "portable"];
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

  flake = {
    homeConfigurations = let
      mkHomeConfig = host: {
        name = "schausberger_${host}";
        value = homeManagerConfiguration {
          modules = homeImports."${lib.getUserHost "schausberger" host}";
          inherit pkgs;
          extraSpecialArgs = mkExtraSpecialArgs host;
        };
      };
    in
      inputs.nixpkgs.lib.listToAttrs (map mkHomeConfig hosts);
  };
}
