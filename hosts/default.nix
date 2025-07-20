{
  homeImports,
  inputs,
  ...
}:
let
  # capitalizeFirstChar = str:
  #   str
  #   |> builtins.substring 0 1
  #   |> lib.strings.toUpper
  #   |> (firstChar: firstChar + builtins.substring 1 (builtins.stringLength str - 1) str);
  inherit (inputs.nixpkgs.lib) nixosSystem;

  inherit (import ../system) desktop laptop;

  specialArgs = {
    secrets = builtins.fromJSON (builtins.readFile "${inputs.self}/secrets/secrets.yaml");
    inherit inputs;
  };

  mkHostConfig =
    {
      hostName,
      baseModules,
      extraModules ? [ ],
    }:
    nixosSystem {
      inherit specialArgs;
      modules =
        baseModules
        ++ [
          {
            networking.hostName = hostName; # |> capitalizeFirstChar;
            _module.args.hostName = hostName;
          }
          (
            { config, ... }:
            {
              home-manager = {
                users.${inputs.self.lib.user}.imports = homeImports."${inputs.self.lib.user}@${hostName}";
                extraSpecialArgs = specialArgs // {
                  inherit hostName;
                  inherit (config._module.args) hostConfig;
                };
              };
            }
          )
        ]
        ++ extraModules;
    };
in
{
  flake.nixosConfigurations = {
    desktop = mkHostConfig {
      hostName = "desktop";
      baseModules = desktop;
      extraModules = [ ./desktop ];
    };

    surface = mkHostConfig {
      hostName = "surface";
      baseModules = laptop;
      extraModules = [ ./surface ];
    };

    pdemu1cml000312 = mkHostConfig {
      hostName = "pdemu1cml000312";
      baseModules = laptop;
      extraModules = [ ./pdemu1cml000312 ];
    };

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [ ./portable ];
    };
  };
}
