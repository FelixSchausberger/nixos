{
  description = "NixOS and Home-Manager flake";

  outputs = inputs:
    let
      user = "schausberger";
      system = "x86_64-linux";
      hostnames = ["desktop" "surface" "portable" "pdemu1cml000312"];
      systemModules = import ./system; # Load system module sets from system/default.nix.
      # Helper function to generate nixosConfigurations
      mkNixosConfiguration = hostname:
        let
          # Select system modules based on hostname.
          # All hosts receive 'platformModules'; 'desktop' gets additional 'gamingSystemModules'.
          hostSystemModules =
            if hostname == "desktop" then
              systemModules.platformModules ++ systemModules.gamingSystemModules
            else # For surface, pdemu1cml000312, portable
              systemModules.platformModules;
        in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
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
      systems = [system];

      imports = [
        ./pre-commit-hooks.nix
      ];

      flake = {
        lib = {
          inherit user;
        };

        nixosConfigurations = builtins.listToAttrs (map (name: {
          inherit name;
          value = mkNixosConfiguration name;
        }) hostnames);

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

        formatter = pkgs.alejandra;
      };
    };

  inputs = {
    localScripts = {
      url = "path:./tools/scripts"; # Path to the local flake
      flake = true;
    };

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
      flake = false;
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
      flake = false;
    };

    yazi-eza-preview = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false;
    };

    yazi-fg = {
      url = "github:DreamMaoMao/fg.yazi";
      flake = false;
    };

    yazi-mount = {
      url = "git+https://github.com/SL-RU/mount.yazi";
      flake = false;
    };

    yazi-starship = {
      url = "github:Rolv-Apneseth/starship.yazi";
      flake = false;
    };

    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };
}
