{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    git-lfs # Git extension for versioning large files
  ];

  programs.git = {
    enable = true;
    userEmail = config.sops.secrets."magazino/email".path;
    extraConfig = {
      init.defaultBranch = "master";
    };
  };

  sops.secrets = {
    "magazino/email" = {};
  };
}
