{inputs, ...}: let
  getUserHost = user: host: "${user}@${host}";

  extraSpecialArgs = {inherit inputs;};

  homeImports = {
    # "${inputs.self.lib.user |> getUserHost <| "desktop"}" = [
    "${getUserHost inputs.self.lib.user "desktop"}" = [
      ../.
      ./desktop
    ];
    # "${inputs.self.lib.user |> getUserHost <| "surface"}" = [
    "${getUserHost inputs.self.lib.user "surface"}" = [
      ../.
      ./surface
    ];
    "${getUserHost inputs.self.lib.user "pdemu1cml000312"}" = [
      ../.
      ./pdemu1cml000312
    ];
    "${getUserHost inputs.self.lib.user "portable"}" = [
      ../.
      ./portable
    ];
  };

  inherit (inputs.hm.lib) homeManagerConfiguration;

  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  # We need to pass this to NixOS' HM module
  _module.args = {inherit homeImports;};

  flake = {
    homeConfigurations = {
      "${inputs.self.lib.user}_desktop" = homeManagerConfiguration {
        modules = homeImports."${inputs.self.lib.user}@desktop";
        inherit pkgs extraSpecialArgs;
      };

      "${inputs.self.lib.user}_surface" = homeManagerConfiguration {
        modules = homeImports."${inputs.self.lib.user}@surface";
        inherit pkgs extraSpecialArgs;
      };

      "${inputs.self.lib.user}_pdemu1cml00312" = homeManagerConfiguration {
        modules = homeImports."${inputs.self.lib.user}@pdemu1cml000312";
        inherit pkgs extraSpecialArgs;
      };

      "${inputs.self.lib.user}_portable" = homeManagerConfiguration {
        modules = homeImports."${inputs.self.lib.user}@portable";
        inherit pkgs extraSpecialArgs;
      };
    };
  };
}
