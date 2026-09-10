{
  homeImports,
  inputs,
  ...
}: let
  # Import configuration toggle
  repoConfig = import ../config.nix;

  inherit (inputs.nixpkgs.lib) nixosSystem optional;

  inherit (import ../system) desktop laptop server;

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
      specialArgs =
        specialArgs
        // {
          # Make hostConfig available to all modules
          # Merge host-specific config with defaults
          hostConfig =
            (inputs.self.lib.hosts.${hostName} or {})
            // {
              inherit (inputs.self.lib) user;
              inherit hostName;
            };
        };
      modules =
        baseModules
        ++ [
          {
            networking.hostName = hostName;
            _module.args.hostName = hostName;
          }
          ({config, ...}: {
            home-manager = {
              users.${inputs.self.lib.user}.imports = homeImports."${inputs.self.lib.user}@${hostName}";
              extraSpecialArgs =
                specialArgs
                // {
                  inherit hostName;
                  # Pass the resolved per-host option (config.hostConfig) so home
                  # modules see the same values the system modules do (e.g.
                  # zellijAutoAttach.sessionName). Merging with the static lib
                  # data keeps non-option fields (ip, description) available.
                  hostConfig =
                    (inputs.self.lib.hosts.${hostName} or {})
                    // config.hostConfig;
                };
            };
          })
        ]
        # Conditionally include Determinate Nix module based on config
        ++ optional repoConfig.useDeterminateNix inputs.determinate.nixosModules.default
        # Add disko module for disk partitioning (required for nixos-anywhere)
        ++ [inputs.disko.nixosModules.disko]
        ++ extraModules;
    };
in {
  # Deployed fleet. These are built by CI (cachix-push, daily-updates) and
  # converged by comin on each host.
  flake.nixosConfigurations = {
    desktop = mkHostConfig {
      hostName = "desktop";
      baseModules = desktop;
      extraModules = [./desktop.nix];
    };

    hp-probook-wsl = mkHostConfig {
      hostName = "hp-probook-wsl";
      baseModules = laptop;
      extraModules = [./hp-probook-wsl.nix];
    };

    m920q = mkHostConfig {
      hostName = "m920q";
      baseModules = server;
      extraModules = [./m920q.nix];
    };
  };

  # Opt-in shelf configurations for hardware that is not currently deployed.
  # Keeping them out of nixosConfigurations means CI does not build them and
  # `nix flake check` does not evaluate them, while the configs stay in-tree
  # for easy revival. Access on demand, for example:
  #   nix build .#legacyConfigurations.surface.config.system.build.toplevel
  # To revive a host, move its entry back into nixosConfigurations.
  flake.legacyConfigurations = {
    surface = mkHostConfig {
      hostName = "surface";
      baseModules = laptop;
      extraModules = [./surface.nix];
    };

    hp-probook-vmware = mkHostConfig {
      hostName = "hp-probook-vmware";
      baseModules = laptop;
      extraModules = [./hp-probook-vmware.nix];
    };
  };
}
