{
  # config,
  pkgs,
  ...
}: {
  imports = [
    ./nixpkgs.nix
    ./substituters.nix
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
        "pipe-operator" # Used by lix, for nix use "pipe-operators"
      ];
      trusted-users = ["root" "@wheel"];
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
      persistent = true;
    };
  };

  environment.systemPackages = [
    pkgs.git # Flakes need git
  ];
}
