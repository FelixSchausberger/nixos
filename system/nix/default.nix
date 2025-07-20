{
  # config,
  pkgs,
  ...
}: {
  imports = [
    ./nixpkgs.nix
    ./shared/substituters.nix
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      # access-tokens = [
      #   "github.com=${config.sops.secrets."github/token".path}"
      # ];
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
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
    };

    gc = {
      automatic = true;
      dates = "daily"; # More frequent cleanup
      options = "--delete-older-than 7d --delete-generations +5"; # Keep last 5 generations, delete older than 7 days
      persistent = true;
    };
  };

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];
}
