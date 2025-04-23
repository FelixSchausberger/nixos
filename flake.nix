{
  description = "NixOS and Home-Manager flake";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./home/profiles
        ./hosts
        ./pre-commit-hooks.nix
      ];

      flake = {
        # Define the username here as a flake-level configuration
        lib = {
          user = "fesch";
        };
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
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typix.url = "github:loqusion/typix";

    yazi.url = "github:sxyazi/yazi";

    yazi-clipboard = {
      url = "git+https://gitee.com/DreamMaoMao/clipboard.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-eza-preview = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-fg = {
      url = "git+https://gitee.com/DreamMaoMao/fg.yazi";
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
