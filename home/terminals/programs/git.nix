{
  pkgs,
  secrets,
  ...
}: {
  home.packages = with pkgs; [
    # https://lgug2z.com/articles/handling-secrets-in-nixos-an-overview/
    git-crypt # Transparent file encryption in git
    graphite-cli # CLI that makes creating stacked git changes fast & intuitive
    pre-commit # A framework for managing and maintaining multi-language pre-commit hooks
  ];

  programs.git = {
    enable = true;
    userName = "Felix Schausberger";
    userEmail = "fel.schausberger@gmail.com";
    delta = {enable = true;};
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      config.credential.helper = "libsecret";
      core.editor = "${pkgs.helix}/bin/hx";
      url = {
        "https://oauth2:${secrets.github.oauth_token}@github.com" = {
          insteadOf = "https://github.com";
        };
      };
    };
    aliases = {
      clone = "git clone";
      fetch = "git fetch";
      ga = "git add -p"; # --interactive
      gcm = "git commit -m";
      gst = "git status";
      log = "git log --graph --abbrev-commit --all";
      # prune = "git filter-branch --index-filter \"git rm -f --cached --ignore-unmatch $1/*\" --prune-empty --tag-name-filter cat -- --all"
      pull = "git pull";
      push = "git push";
    };
  };
}
