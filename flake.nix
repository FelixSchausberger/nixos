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
        # Utility functions (keep minimal)
        lib = {
          mkHost = import ./lib/mkHost.nix;
          user = "schausberger"; # Default user
        };
      };

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          basalt = pkgs.callPackage ./pkgs/basalt {};
          lumen = pkgs.callPackage ./pkgs/lumen {};
          vigiland = pkgs.callPackage ./pkgs/vigiland {};
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Nix tools
            alejandra
            git

            # Documentation and formatting
            nodejs # For prettier
            nodePackages.prettier

            # Development tools
            pre-commit
          ];

          name = "nixos-config";
          DIRENV_LOG_FORMAT = "";

          shellHook = ''
            ${config.pre-commit.installationScript}
            echo "Guten Morgen!"
          '';
        };

        formatter = pkgs.alejandra;
      };
    };

  inputs = {
    # Core Nix infrastructure
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System utilities
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sopswarden = {
      url = "github:pfassina/sopswarden/unstable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.follows = "sops-nix";
    };

    # Desktop environments
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    # Window manager and system tools
    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wayland-pipewire-idle-inhibit = {
      url = "github:rafaelrc7/wayland-pipewire-idle-inhibit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Editors
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix.url = "github:helix-editor/helix";

    # Applications
    bluetui = {
      url = "github:pythops/bluetui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typix.url = "github:loqusion/typix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # File manager and plugins
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
      flake = false;
    };

    # Utilities
    nix-index-db = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-inspect.url = "github:bluskript/nix-inspect";
    nur.url = "github:nix-community/NUR";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local packages and tools
    scripts.url = "./tools/scripts";

    # Themes
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false;
    };
  };
}
