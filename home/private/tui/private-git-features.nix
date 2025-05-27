# Augments base Git config with settings for private use (e.g., personal email, GitHub token).
{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    act # Run your GitHub Actions locally
    lazygit # A simple terminal UI for git commands
  ];

  programs.git.userEmail = "131732042+FelixSchausberger@users.noreply.github.com";
  programs.git.extraConfig = {
    github.token = config.sops.secrets."github/token".path;
    init.defaultBranch = "main";
  };

  sops.secrets."github/token" = {};
}
