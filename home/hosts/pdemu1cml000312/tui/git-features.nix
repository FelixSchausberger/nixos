# home/hosts/pdemu1cml000312/tui/git-features.nix
# Augments base Git config with work-specific settings for this host.
{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    git-lfs
  ];

  sops.secrets."magazino/email" = {
    mode = "0400";
  };

  programs.git.extraConfig = {
    init.defaultBranch = "master"; # Work preference
    # Ensure include.path uses an absolute path or a path relative to home
    include.path = "${config.home.homeDirectory}/.gitconfig.local";
  };

  home.activation.setupGitEmail = config.lib.dag.entryAfter ["writeBoundary"] ''
    if [ -f "${config.sops.secrets."magazino/email".path}" ]; then
      email=$(${pkgs.coreutils}/bin/cat "${config.sops.secrets."magazino/email".path}")
      # Ensure the path to .gitconfig.local is correct, using absolute path
      echo "[user]" > "''${config.home.homeDirectory}/.gitconfig.local"
      echo "    email = $email" >> "''${config.home.homeDirectory}/.gitconfig.local"
    fi
  '';
}
