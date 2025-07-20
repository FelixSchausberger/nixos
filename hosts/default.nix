{
  homeImports,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) nixosSystem;

  inherit (import ../system) desktop laptop;

  specialArgs = {
    secrets = builtins.fromJSON (builtins.readFile "${inputs.self}/secrets/secrets.yaml");
    inherit inputs;
  };

  mkHostConfig = {
    hostName,
    baseModules,
    extraModules ? [],
  }:
    nixosSystem {
      inherit specialArgs;
      modules =
        baseModules
        ++ [
          {
            networking.hostName = hostName;
            _module.args.hostName = hostName;
          }
          (
            _: {
              home-manager = {
                users.${inputs.self.lib.user}.imports = homeImports."${inputs.self.lib.user}@${hostName}";
                extraSpecialArgs =
                  specialArgs
                  // {
                    inherit hostName;
                  };
              };
            }
          )
        ]
        ++ extraModules;
    };
in {
  flake.nixosConfigurations = {
    desktop = mkHostConfig {
      hostName = "desktop";
      baseModules = desktop;
      extraModules = [./desktop];
    };

    surface = mkHostConfig {
      hostName = "surface";
      baseModules = laptop;
      extraModules = [./surface];
    };

    pdemu1cml000312 = mkHostConfig {
      hostName = "pdemu1cml000312";
      baseModules = laptop;
      extraModules = [./pdemu1cml000312];
    };

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [./portable];
    };
  };
}
