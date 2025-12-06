{
  description = "NixOS and Home-Manager flake";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cache.garnix.io"
      "https://felixschausberger.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://pre-commit-hooks.cachix.org"
      "https://yazi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "felixschausberger.cachix.org-1:vCZvKWZ13V7CxC7HjRPqZJTwcKLJaaxYnfQsUIkDFaE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt4="
      "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
      "yazi.cachix.org-1:ot2ynJHj5l8T+FaRjblM6YV3sLzuEEr/KK10lC3aIaA="
    ];
    # Cache robustness settings
    narinfo-cache-positive-ttl = 3600; # 1 hour for R2 presigned URLs
    connect-timeout = 5; # Fast fail on connection issues
    stalled-download-timeout = 30; # Detect stalled downloads quickly

    # Determinate Nix-specific settings (ignored by standard Nix)
    # lazy-trees enables faster evaluation by only copying necessary files
    lazy-trees = true;
  };

  inputs = {
    # === CORE INPUTS (Used by all hosts) ===
    # Core Nix infrastructure (always needed)

    # Nixpkgs sources - toggle via config.nix useDeterminateNix boolean
    # Standard Nix (GitHub nixos-unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Determinate Nix (FlakeHub with semver)
    # See: https://docs.determinate.systems/flakehub/concepts/semver#nixpkgs
    nixpkgs-flakehub.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System utilities (shared by TUI and GUI)
    # Determinate Nix modules (only used when useDeterminateNix = true)
    # See: https://github.com/DeterminateSystems/determinate?tab=readme-ov-file#installing-using-our-nix-flake
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-inspect.url = "github:bluskript/nix-inspect";
    nur.url = "github:nix-community/NUR";
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

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
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
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
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
        lib = rec {
          # Centralized defaults - single source of truth
          defaults = import ./lib/defaults.nix;
          fonts = import ./lib/fonts.nix;
          catppuccinColors = import ./modules/home/themes/catppuccin-colors.nix;
          hosts = import ./lib/hosts.nix;

          # Legacy compatibility - keep existing API
          mkHost = import ./lib/mkHost.nix;
          profiles = profileLib;
          inherit (defaults.system) user;
          inherit (defaults) personalInfo;
          inherit (defaults) paths;
        };
      };

      perSystem = {pkgs, ...}: {
        # Expose nixpkgs for easier local builds (e.g., nix build .#fishPlugins.autopair)
        legacyPackages = pkgs;

        packages = {
          lumen = pkgs.callPackage ./pkgs/lumen {};
          vigiland = pkgs.callPackage ./pkgs/vigiland {};
          # wlsleephandler-rs = pkgs.callPackage ./pkgs/wlsleephandler-rs {}; # Disabled until proper hash is available

          # Installation tools
          install-nixos = pkgs.callPackage ./pkgs/install-nixos {};

          # MCP servers
          mcp-language-server = pkgs.callPackage ./pkgs/mcp-language-server {};

          # MOTD
          trotd = pkgs.callPackage ./pkgs/trotd {};

          # Minimal installer ISO (fast rebuilds for testing)
          installer-iso-minimal = inputs.nixos-generators.nixosGenerate {
            inherit (pkgs.stdenv.hostPlatform) system;
            format = "install-iso";
            modules = [
              ./hosts/installer-minimal
            ];
            specialArgs = {
              inherit inputs;
              repoConfig = import ./config.nix;
            };
          };

          # Full installer ISO (comprehensive recovery environment)
          installer-iso-full = inputs.nixos-generators.nixosGenerate {
            inherit (pkgs.stdenv.hostPlatform) system;
            format = "install-iso";
            modules = [
              ./hosts/installer
            ];
            specialArgs = {
              inherit inputs;
              repoConfig = import ./config.nix;
            };
          };

          # Alias for backwards compatibility
          installer-iso = self.packages.${pkgs.stdenv.hostPlatform.system}.installer-iso-full;
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
            ssh-to-age
            statix
            taplo
            inputs.namaka.packages.${pkgs.stdenv.hostPlatform.system}.default # Snapshot testing
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
