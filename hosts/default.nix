{
  homeImports,
  inputs,
  lib,
  ...
}: let
  capitalizeFirstChar = str:
    str
    |> builtins.substring 0 1
    |> lib.strings.toUpper
    |> (firstChar: firstChar + builtins.substring 1 (builtins.stringLength str - 1) str);

  inherit (inputs.nixpkgs.lib) nixosSystem;

  inherit (import "${inputs.self}/system") desktop laptop;

  specialArgs = {
    secrets = builtins.fromJSON (builtins.readFile "${inputs.self}/secrets/secrets.json");
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
            networking.hostName = hostName |> capitalizeFirstChar;
            _module.args.hostName = hostName;
          }
          {
            home-manager = {
              users.${inputs.self.lib.user}.imports =
                homeImports."${inputs.self.lib.user}@${hostName}";
              extraSpecialArgs = specialArgs // {inherit hostName;};
            };
          }
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

    thinkpad = mkHostConfig {
      hostName = "thinkpad";
      baseModules = laptop;
      extraModules = [./thinkpad];
    };

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [./portable];
    };
  };
}
