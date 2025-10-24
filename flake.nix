{
  description = "NixOS and Home-Manager flake";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nixpkgs-schausberger.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixpkgs-schausberger.cachix.org-1:BdcD4tXljP3BQGhm9mUjmLkkPwl+7IFcl1JX5CsrIfE="
    ];
  };

  inputs = {
    # === CORE INPUTS (Used by all hosts) ===
    # Core Nix infrastructure (always needed)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System utilities (shared by TUI and GUI)
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
    gitignore-nix = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    namaka = {
      url = "github:nix-community/namaka";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ccusage.url = "github:tnmt/ccusage-flake";

    # Editors (used by both TUI and GUI hosts)
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix.url = "github:helix-editor/helix";

    # File manager (used by both TUI and GUI)
    yazi.url = "github:sxyazi/yazi";

    # Yazi plugins
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
      url = "github:SL-RU/mount.yazi";
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

    nix-index-db = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-inspect.url = "github:bluskript/nix-inspect";
    nur.url = "github:nix-community/NUR";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # TUI applications (used by both profiles)
    bluetui = {
      url = "github:pythops/bluetui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    zjstatus = {
      url = "github:dj95/zjstatus";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installation tools (useful for portable/recovery)
    nixos-wizard = {
      url = "github:km-clay/nixos-wizard";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # === GUI-SPECIFIC INPUTS (Only used by GUI hosts) ===
    # Desktop environment managers
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Desktop environments
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
    ala-lape = {
      url = "git+https://git.madhouse-project.org/algernon/ala-lape.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cthulock = {
      url = "github:FriederHannenheim/cthulock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GUI Applications
    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typix.url = "github:loqusion/typix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Themes
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false;
    };
  };

  outputs = inputs: let
    # Import profile detection utilities
    profileLib = import ./lib/profiles.nix;
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({self, ...}: {
      systems = ["x86_64-linux"];

      imports = [
        ./home/profiles
        ./hosts
      ];

      flake = {
        # Utility functions
        lib = {
          mkHost = import ./lib/mkHost.nix;
          profiles = profileLib;
          user = "schausberger"; # Default user

          # Personal information variables
          personalInfo = {
            name = "Felix Schausberger";
          };

          # Common paths
          paths = {
            nixosConfig = "/per/etc/nixos";
            obsidianVault = "/per/home/schausberger/Documents/Obsidian";
            homeDir = "/home/schausberger";
            repos = "/per/repos";
          };
        };
      };

      perSystem = {pkgs, ...}: {
        packages = {
          lumen = pkgs.callPackage ./pkgs/lumen {};
          vigiland = pkgs.callPackage ./pkgs/vigiland {};
          # wlsleephandler-rs = pkgs.callPackage ./pkgs/wlsleephandler-rs {}; # Disabled until proper hash is available

          # Zellij plugins
          zellij-ghost = pkgs.callPackage ./pkgs/ghost {};

          # MCP servers
          mcp-language-server = pkgs.callPackage ./pkgs/mcp-language-server {};

          # VMDK builder for portable workstation
          vmdk-portable = pkgs.callPackage ./tools/vmdk-builder {inherit inputs;};

          # ZFS setup tool
          zfs-nixos-setup = pkgs.rustPlatform.buildRustPackage {
            pname = "zfs-nixos-setup";
            version = "0.1.0";
            src = inputs.gitignore-nix.lib.gitignoreSource ./tools/zfs-nixos-setup;
            cargoLock.lockFile = ./tools/zfs-nixos-setup/Cargo.lock;
            nativeBuildInputs = with pkgs; [pkg-config];
            buildInputs = [];
          };
        };

        # Snapshot tests using namaka
        checks = inputs.namaka.lib.load {
          src = ./tests;
          inputs = {
            namaka = inputs.namaka.lib;
            flake = self;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            bashInteractive # Use interactive bash with full features
            deadnix
            fish
            git
            nodePackages.prettier
            pre-commit-hook-ensure-sops
            prek
            statix
            taplo
            inputs.namaka.packages.${pkgs.system}.default # Snapshot testing
          ];

          name = "nixos-config";

          shellHook = ''
            prek install
          '';
        };

        formatter = pkgs.alejandra;
      };
    });
}
