# Augments base Git config with settings for work use (e.g., work email, LFS, specific include paths).
{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    git-lfs # Git extension for versioning large files
  ];

  programs.git.extraConfig = {
    init.defaultBranch = "master"; # Work preference
    include.path = "${config.home.homeDirectory}/.gitconfig.local";
  };

  sops.secrets."magazino/email" = {
    mode = "0400";
  };

  home.activation.setupGitEmail = config.lib.dag.entryAfter ["writeBoundary"] ''
    if [ -f "${config.sops.secrets."magazino/email".path}" ]; then
      email=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."magazino/email".path})
      echo "[user]" > ''${config.home.homeDirectory}/.gitconfig.local
      echo "    email = $email" >> ''${config.home.homeDirectory}/.gitconfig.local
    fi
  '';
}
