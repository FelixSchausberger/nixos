{
  description = "NixOS and Home-Manager flake";

  outputs = inputs:
    let
      user = "schausberger"; # Define user here for convenience
      system = "x86_64-linux"; # Define system here for convenience
      hostnames = ["desktop" "surface" "portable" "pdemu1cml000312"]; # Define hostnames
      # Load system module sets from system/default.nix.
      systemModules = import ./system; # This loads system/default.nix
      # Helper function to generate nixosConfigurations
      mkNixosConfiguration = hostname:
          let
            # Dynamically select system modules based on hostname and defined roles.
            hostSystemModules =
              if hostname == "desktop" then
                systemModules.standardSystemModules ++ systemModules.gamingSystemModules
              else if hostname == "surface" || hostname == "pdemu1cml000312" || hostname == "portable" then
                systemModules.standardSystemModules
              else []; # Should not happen with the defined hostnames list
          in
          inputs.nixpkgs.lib.nixosSystem {
            inherit system; # system = "x86_64-linux";
            specialArgs = {inherit inputs;};
            modules = [
              ./hosts/${hostname}/default.nix
              inputs.sops-nix.nixosModules.sops
              inputs.home-manager.nixosModules.home-manager
            ] ++ hostSystemModules;
          };
      # Helper function to generate homeConfigurations
      mkHomeConfiguration = hostname:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {inherit inputs;};
          modules = [
            ./home/default.nix
            ./home/profiles/${hostname}/default.nix
          ];
        };
    in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [system]; # Use the defined system variable

      imports = [
        # ./home/profiles # Removed as per instructions
        # ./hosts # Removed as per instructions
        ./pre-commit-hooks.nix
      ];

      flake = {
        # Define the username here as a flake-level configuration
        lib = {
          inherit user; # Use the defined user variable
        };

        # NixOS configurations
        nixosConfigurations = builtins.listToAttrs (map (name: {
          inherit name;
          value = mkNixosConfiguration name;
        }) hostnames);

        # Home Manager configurations
        homeConfigurations = builtins.listToAttrs (map (name: {
          name = "${user}-${name}";
          value = mkHomeConfiguration name;
        }) hostnames);
      };

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          lumen = pkgs.callPackage ./system/nix/pkgs/lumen {};
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.alejandra
            pkgs.git
            pkgs.nodePackages.prettier
          ];
          name = "dots";
          DIRENV_LOG_FORMAT = "";
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';
        };

        formatter = pkgs.alejandra; # Ensure alejandra is used for formatting
      };
    };

  inputs = {
    # Local Flakes
    localScripts = {
      url = "path:./home/scripts"; # Ensures it points to the subdirectory
      flake = true; # Explicitly state it's a flake
    };

    # Global, so they can be `.follow`ed
    systems.url = "github:nix-systems/default-linux";

    flake-compat.url = "github:edolstra/flake-compat";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs = {
      follows = "nixos-cosmic/nixpkgs";
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    # Rest of inputs, alphabetical order
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false; # This repo doesn't contain a flake.nix
    };

    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helix.url = "github:helix-editor/helix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nix-index-db = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # scripts.url = "./home/scripts";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix/24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typix.url = "github:loqusion/typix";

    yazi.url = "github:sxyazi/yazi";

    yazi-clipboard = {
      url = "github:DreamMaoMao/clipboard.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-eza-preview = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-fg = {
      url = "github:DreamMaoMao/fg.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-mount = {
      url = "git+https://github.com/SL-RU/mount.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-starship = {
      url = "github:Rolv-Apneseth/starship.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false; # This repo doesn't contain a flake.nix
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };
}
