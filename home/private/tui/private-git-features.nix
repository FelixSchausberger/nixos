# home/private/tui/private-git-features.nix
# Augments base Git config with settings for private use.
{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    act
    lazygit
  ];

  programs.git.userEmail = "131732042+FelixSchausberger@users.noreply.github.com";
  programs.git.extraConfig = {
    github.token = config.sops.secrets."github/token".path;
    init.defaultBranch = "main";
  };

  sops.secrets."github/token" = {};
}
