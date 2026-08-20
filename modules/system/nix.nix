{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Determinate Nix configuration handled by nixosModules.default
  # Nixpkgs configuration
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      # Keep aliases enabled - required for deprecated packages still using old names
      # Note: Some aliases like wrapGAppsHook have been converted to throw errors
      # and cannot be overridden via overlays due to evaluation order
      # allowAliases = true; # disabled for now - see https://github.com/NixOS/nixpkgs/pull/...
    };
    overlays = [
      inputs.nur.overlays.default
      # Custom overlay for TUI-specific packages
      (final: prev: let
        zellijPlugins = prev.callPackage ../../pkgs/zellij-plugins {};
        zjstatus = prev.zellijPlugins.zjstatus;
      in {
        inherit zjstatus;
        "zjstatus-hints" = zellijPlugins.zjstatus-hints;
        harpoon-plugin = zellijPlugins.harpoon;
        inherit (zellijPlugins) zellij-forgot;
        dssh = final.callPackage ../../pkgs/dssh {};

        # Align the tree-sitter-rust grammar with the queries shipped by the
        # steelix fork (a Helix master snapshot), which still use the
        # `type_parameter` node that newer tree-sitter-rust releases renamed to
        # constrained_type_parameter/optional_type_parameter/const_parameter.
        # Mismatch caused: "Failed to compile highlights for 'rust': invalid
        # node type \"type_parameter\"". Pin to upstream Helix-master's rev.
        # Uses inputs.nixpkgs (not pkgs.path) so the file is realized under lazy-trees.
        helix = prev.helix.override {
          lockedGrammars =
            lib.recursiveUpdate
            (lib.importJSON "${inputs.nixpkgs}/pkgs/by-name/he/helix/grammars.json")
            {
              rust.nurl.args = {
                hash = "sha256-Ls6tB6IxXDQDWwx0BJ7RgbheelC4MH8z97E7wwhkDcY=";
                owner = "tree-sitter";
                repo = "tree-sitter-rust";
                rev = "77a3747266f4d621d0757825e6b11edcbf991ca5";
              };
            };
        };
      })
    ];
  };

  nix = {
    settings = {
      # Basic settings
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      accept-flake-config = true; # Trust flake nixConfig settings (safe for own configurations)
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
      warn-dirty = false;

      # GitHub token authentication (using sops secret)
      # Note: This is set via extraOptions since it needs runtime secret path
      # access-tokens config is handled below in extraOptions

      # WSL-specific configuration for better performance
      use-sqlite-wal = true; # Better database performance on WSL

      # Network optimization for faster downloads
      max-substitution-jobs = 4; # Parallel downloads
      http-connections = 25; # More HTTP connections
      connect-timeout = 15; # Allow more time for slow caches
      stalled-download-timeout = 600; # 10 minutes for large/slow downloads

      # Build optimization
      # Limit parallelism to prevent "too many files open" during evaluation
      # High values exhaust file handles when evaluating multiple host configurations
      cores = lib.mkDefault 4; # Limit cores per build (was 0 = all)
      max-jobs = lib.mkDefault 4; # Limit parallel jobs (was "auto")
      keep-going = true; # Continue building other derivations on failure

      # Store optimization for better performance
      keep-outputs = lib.mkDefault true; # Keep build dependencies for faster rebuilds
      keep-derivations = lib.mkDefault true; # Keep derivations for faster evaluation

      # Disk space management
      min-free = 5368709120; # 5GB - trigger GC when less than 5GB free
      max-free = 10737418240; # 10GB - stop GC when 10GB free

      # Build performance improvements
      builders-use-substitutes = true; # Allow builders to use substitutes
      require-sigs = true; # Security: require signatures

      # Evaluation performance
      eval-cache = true; # Cache evaluation results

      # Substituters and caches
      extra-substituters = [
        # Primary cache - fastest and most reliable
        "https://cache.nixos.org?priority=1"

        # Very commonly used packages - high priority
        "https://nix-community.cachix.org?priority=5"

        # Personal cache for custom builds
        "https://felixschausberger.cachix.org?priority=7"

        # Project-specific caches - medium priority
        "https://cosmic.cachix.org?priority=10"
        "https://hyprland.cachix.org?priority=12"
        "https://walker.cachix.org?priority=13"
        "https://walker-git.cachix.org?priority=14"
        "https://helix.cachix.org?priority=15"
        "https://yazi.cachix.org?priority=20"
        "https://claude-code.cachix.org?priority=21"
        "https://devenv.cachix.org?priority=25"

        # Additional popular caches to reduce compilation
        "https://nixpkgs-unfree.cachix.org?priority=30"

        # Determinate Systems cache for Determinate Nix binaries
        "https://install.determinate.systems?priority=35"
      ];

      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "felixschausberger.cachix.org-1:vCZvKWZ13V7CxC7HjRPqZJTwcKLJaaxYnfQsUIkDFaE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

        # Project-specific caches
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
        "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt4="

        # FlakeHub key is injected by Determinate Nix when enabled
      ];
    };
  };

  # Disable default nix gc service (we use custom maintenance service)
  nix.gc.automatic = false;

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];

  programs.nix-index-database.comma.enable = true;

  # GitHub token configuration (optional - only when sops is available)
  sops.secrets."github/token" = lib.mkIf (config.sops.age.keyFile != null) {
    mode = "0440";
    group = "wheel";
  };

  # Use sops template to generate nix.conf with GitHub token (only when sops available)
  sops.templates."nix-access-tokens.conf" = lib.mkIf (config.sops.age.keyFile != null) {
    content = ''
      access-tokens = github.com=${config.sops.placeholder."github/token"}
    '';
    owner = "root";
    group = "wheel";
    mode = "0440";
  };

  # Include the generated config in Nix's extraOptions (only when template exists)
  nix.extraOptions = lib.mkIf (config.sops.age.keyFile != null) ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';
}
