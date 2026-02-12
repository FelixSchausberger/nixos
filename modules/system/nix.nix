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
      permittedInsecurePackages = [
        "electron-25.9.0"
      ];
      allowBroken = true;
      # Keep aliases enabled - required for deprecated packages still using old names
      # Note: Some aliases like wrapGAppsHook have been converted to throw errors
      # and cannot be overridden via overlays due to evaluation order
      allowAliases = true;
    };
    overlays = [
      inputs.nur.overlays.default
      # Custom overlay for TUI-specific packages
      (final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
        helix-steel = final.callPackage ../../pkgs/helix-steel {};
        helix-steel-modules = final.callPackage ../../pkgs/helix-steel-modules {};
        scooter-hx = final.callPackage ../../pkgs/scooter-hx {};
      })
    ];
  };

  nix = {
    settings = {
      # Basic settings
      experimental-features = ["nix-command" "flakes" "pipe-operators"];
      accept-flake-config = true; # Trust flake nixConfig settings (safe for own configurations)
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];
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
      cores = lib.mkDefault 0; # Use all CPU cores
      max-jobs = lib.mkDefault "auto"; # Auto-detect job count
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

      # GitHub access token from sops secrets
      netrc-file = "/etc/nix/netrc";

      # Substituters and caches
      substituters = [
        # Primary cache - fastest and most reliable
        "https://cache.nixos.org?priority=1"

        # Garnix CI cache - high priority since our CI builds populate it
        "https://cache.garnix.io?priority=3"

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
        "https://devenv.cachix.org?priority=25"

        # Additional popular caches to reduce compilation
        "https://nixpkgs-unfree.cachix.org?priority=30"

        # Determinate Systems cache for Determinate Nix binaries
        "https://install.determinate.systems?priority=35"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "felixschausberger.cachix.org-1:vCZvKWZ13V7CxC7HjRPqZJTwcKLJaaxYnfQsUIkDFaE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

        # Garnix CI cache
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

        # Project-specific caches
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
        "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt4="

        # Determinate Systems / FlakeHub cache
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
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
