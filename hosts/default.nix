{
  homeImports,
  inputs,
  ...
}: let
  # Import configuration toggle
  repoConfig = import ../config.nix;

  # Select nixpkgs based on configuration
  # To disable FlakeHub during installation, use: ln -sf config-installer.nix config.nix
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
        # Add disko module for disk partitioning (required for nixos-anywhere)
        ++ [inputs.disko.nixosModules.disko]
        ++ extraModules;
    };
in {
  flake.nixosConfigurations = {
    desktop = mkHostConfig {
      hostName = "desktop";
      baseModules = desktop;
      extraModules = [
        ./desktop/default.nix
        ./desktop/hardware/hardware-configuration.nix
      ];
    };

    surface = mkHostConfig {
      hostName = "surface";
      baseModules = laptop;
      extraModules = [
        ./surface/default.nix
        ./surface/hardware/hardware-configuration.nix
      ];
    };

    portable = mkHostConfig {
      hostName = "portable";
      baseModules = desktop;
      extraModules = [
        ./portable/default.nix
        ./portable/hardware/hardware-configuration.nix
      ];
    };

    hp-probook-wsl = mkHostConfig {
      hostName = "hp-probook-wsl";
      baseModules = laptop;
      extraModules = [
        ./hp-probook-wsl/default.nix
        ./hp-probook-wsl/hardware/hardware-configuration.nix
      ];
    };

    hp-probook-vmware = mkHostConfig {
      hostName = "hp-probook-vmware";
      baseModules = laptop;
      extraModules = [
        ./hp-probook-vmware/default.nix
        ./hp-probook-vmware/hardware/hardware-configuration.nix
      ];
    };
  };
}
