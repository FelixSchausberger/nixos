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
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };
  };

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];
}
