{
  homeImports,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs.lib) nixosSystem;

  inherit (import ../system) desktop laptop;

  specialArgs = {
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
          inputs.determinate.nixosModules.default
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

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [./portable];
    };

    hp-probook-wsl = mkHostConfig {
      hostName = "hp-probook-wsl";
      baseModules = laptop;
      extraModules = [./hp-probook-wsl];
    };
  };
}
