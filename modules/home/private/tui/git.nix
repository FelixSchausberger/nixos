{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # graphite-cli # CLI that makes creating stacked git changes fast & intuitive
    lazygit # A simple terminal UI for git commands
  ];

  programs.git = {
    enable = true;
    userEmail = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
    extraConfig = {
      github.token = "${config.sops.secrets."github/token".path}";
      init.defaultBranch = "main";
    };
  };

  sops.secrets = {
    "github/token" = {};
  };
}
