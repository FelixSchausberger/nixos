# Augments base Git config with settings for work use (e.g., work email, LFS, specific include paths).
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    git-lfs # Git extension for versioning large files
  ];

  programs.git.extraConfig = {
    init.defaultBranch = "master";
    # Ensure include.path uses an absolute path or a path relative to home
    include.path = "${config.home.homeDirectory}/.gitconfig.local";
  };

  # TEMPORARILY DISABLED - SOPS SECRETS CAUSING BUILD FAILURES
  # sops.secrets."magazino/email" = {
  #   mode = "0400";
  # };

  # TEMPORARILY DISABLED - USING HARDCODED EMAIL INSTEAD OF SOPS
  # home.activation.setupGitEmail = config.lib.dag.entryAfter ["writeBoundary"] ''
  #   if [ -f "${config.sops.secrets."magazino/email".path}" ]; then
  #     email=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."magazino/email".path})
  #     echo "[user]" > ~/.gitconfig.local
  #     echo "    email = $email" >> ~/.gitconfig.local
  #   fi
  # '';

  home.activation.setupGitEmail = config.lib.dag.entryAfter ["writeBoundary"] ''
    echo "[user]" > ~/.gitconfig.local
    echo "    email = schausberger@magazino.eu" >> ~/.gitconfig.local
  '';
}
