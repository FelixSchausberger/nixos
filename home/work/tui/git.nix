{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    git-lfs # Git extension for versioning large files
  ];

  sops.secrets = {
    "magazino/email" = {
      mode = "0400";
    };
  };

  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "master";
      include.path = "${config.home.homeDirectory}/.gitconfig.local";
    };
  };

  home.activation.setupGitEmail = config.lib.dag.entryAfter ["writeBoundary"] ''
    if [ -f "${config.sops.secrets."magazino/email".path}" ]; then
      email=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."magazino/email".path})
      echo "[user]" > ~/.gitconfig.local
      echo "    email = $email" >> ~/.gitconfig.local
    fi
  '';
}
