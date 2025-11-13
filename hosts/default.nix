{
  homeImports,
  inputs,
  ...
}: let
  # Import configuration toggle
  repoConfig = import ../config.nix;

  # Select nixpkgs based on configuration
  pkgs =
    if repoConfig.useDeterminateNix
    then inputs.nixpkgs-flakehub
    else inputs.nixpkgs;

  inherit (pkgs.lib) nixosSystem optional;

  inherit (import ../system) desktop laptop;

  specialArgs = {
    inherit inputs;
    inherit repoConfig;
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
        # Conditionally include Determinate Nix module based on config
        ++ optional repoConfig.useDeterminateNix inputs.determinate.nixosModules.default
        ++ extraModules;
    };
in {
  flake.nixosConfigurations = {
    desktop = mkHostConfig {
      hostName = "desktop";
      baseModules = desktop;
      extraModules = [./desktop.nix];
    };

    surface = mkHostConfig {
      hostName = "surface";
      baseModules = laptop;
      extraModules = [./surface.nix];
    };

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [./portable.nix];
    };

    hp-probook-wsl = mkHostConfig {
      hostName = "hp-probook-wsl";
      baseModules = laptop;
      extraModules = [./hp-probook-wsl.nix];
    };

    hp-probook-vmware = mkHostConfig {
      hostName = "hp-probook-vmware";
      baseModules = laptop;
      extraModules = [./hp-probook-vmware.nix];
    };
  };
}
