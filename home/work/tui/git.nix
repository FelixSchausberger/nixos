{pkgs, ...}: {
  home.packages = with pkgs; [
    git-lfs # Git extension for versioning large files
  ];

  programs.git = {
    enable = true;
    userEmail = "schausberger@magazino.eu";
    extraConfig = {
      init.defaultBranch = "master";
    };
  };
}
