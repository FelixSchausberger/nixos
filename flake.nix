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
        # Utility functions
        lib = {
          mkHost = import ./lib/mkHost.nix;
          user = "schausberger"; # Default user

          # Personal information variables
          personalInfo = {
            name = "Felix Schausberger";
            email = "fel.schausberger@gmail.com";
            workEmail = "schausberger@magazino.ai";
          };

          # Common paths
          paths = {
            nixosConfig = "/per/etc/nixos";
            obsidianVault = "/per/vault/Brain";
            homeDir = "/home/schausberger";
            repos = "/per/repos";
          };
        };
      };

      # Modern deployment with nixos-anywhere (faster, more reliable)
      # Usage: nix run .#nixos-anywhere -- --flake .#hostname root@target-ip
      flake.packages.x86_64-linux.nixos-anywhere = inputs.nixos-anywhere.packages.x86_64-linux.default;

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          basalt = pkgs.callPackage ./pkgs/basalt {};
          lumen = pkgs.callPackage ./pkgs/lumen {};
          vigiland = pkgs.callPackage ./pkgs/vigiland {};

          # VMDK builder for portable workstation
          vmdk-portable = pkgs.callPackage ./tools/vmdk-builder {inherit inputs;};

          # ZFS setup tool
          zfs-nixos-setup = pkgs.rustPlatform.buildRustPackage {
            pname = "zfs-nixos-setup";
            version = "0.1.0";
            src = ./tools/zfs-nixos-setup;
            cargoLock.lockFile = ./tools/zfs-nixos-setup/Cargo.lock;
            nativeBuildInputs = with pkgs; [pkg-config];
            buildInputs = [];
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            bashInteractive # Use interactive bash with full features
            git
            pre-commit
          ];

          name = "nixos-config";

          shellHook = ''
            ${config.pre-commit.installationScript}
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
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop environments
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    hyprland.url = "github:hyprwm/Hyprland";
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

    # Deployment utilities
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    # Themes
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false;
    };

    # Installation tools (optional for portable host)
    nixos-wizard = {
      url = "github:km-clay/nixos-wizard";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
