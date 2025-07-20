{
  nix.settings = {
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
    ];
  };
}
