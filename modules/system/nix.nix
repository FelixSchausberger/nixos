{
  inputs,
  pkgs,
  ...
}: {
  # Determinate Nix configuration handled by nixosModules.default
  # Nixpkgs configuration
  nixpkgs = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "electron-25.9.0"
      ];
      allowBroken = true;
    };
    overlays = [
      inputs.nur.overlays.default
      # Custom overlay for TUI-specific packages
      (_: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      })
    ];
  };

  nix.settings = {
    # Basic settings
    experimental-features = ["nix-command" "flakes" "pipe-operators"];
    lazy-trees = true; # Enable lazy trees for faster evaluations and reduced disk usage
    auto-optimise-store = true;
    trusted-users = ["root" "@wheel"];
    warn-dirty = false;

    # SSL/TLS configuration for secure downloads (allow override)
    ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    # WSL-specific configuration for better performance
    use-sqlite-wal = true; # Better database performance on WSL

    # Network optimization for faster downloads
    max-substitution-jobs = 4; # Parallel downloads
    http-connections = 25; # More HTTP connections
    connect-timeout = 5; # Faster timeout

    # Build optimization
    cores = 0; # Use all CPU cores
    max-jobs = "auto"; # Auto-detect job count
    keep-going = true; # Continue building other derivations on failure

    # Store optimization for better performance
    keep-outputs = true; # Keep build dependencies for faster rebuilds
    keep-derivations = true; # Keep derivations for faster evaluation

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

      # Very commonly used packages - high priority
      "https://nix-community.cachix.org?priority=5"

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

      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt4="

      # Determinate Systems / FlakeHub cache
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  # Disable default nix gc service (we use custom maintenance service)
  nix.gc.automatic = false;

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];
}
