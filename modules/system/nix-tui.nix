{
  inputs,
  pkgs,
  ...
}: {
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
    ];
  };

  nix.settings = {
    # Basic settings
    experimental-features = ["nix-command" "flakes" "pipe-operators"];
    auto-optimise-store = true;
    trusted-users = ["root" "@wheel"];
    warn-dirty = false;

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

    # TUI-optimized substituters (minimal caches for faster evaluation)
    substituters = [
      # Primary cache - fastest and most reliable
      "https://cache.nixos.org?priority=1"

      # Essential community packages
      "https://nix-community.cachix.org?priority=5"

      # TUI-specific caches only
      "https://helix.cachix.org?priority=10"
      "https://yazi.cachix.org?priority=15"

      # General development tools
      "https://devenv.cachix.org?priority=20"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  # Disable default nix gc service (we use custom maintenance service)
  nix.gc.automatic = false;

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];
}
