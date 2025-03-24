{
  nix.settings = {
    substituters = [
      # High priority since it's almost always used
      "https://cache.nixos.org?priority=10"

      "https://cosmic.cachix.org/"
      "https://helix.cachix.org"
      "https://cache.lix.systems"
      "https://nix-community.cachix.org"
      "https://yazi.cachix.org"

      # Magazino
      "https://cache.nixos.org/"
      "s3://magazino-nix-binary-cache?endpoint=https://storage.googleapis.com&profile=gcp"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="

      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="

      # Magazino
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "gcp-bucket:p0OfsD9+oKLrXbcFyk5Mi1sWHjQbTRfE92XOjHdw/Ho="
    ];
  };
}
