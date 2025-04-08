{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.self.packages.${pkgs.system}.lumen # Instant AI Git Commit message, Git changes summary from the CLI
    pre-commit # A framework for managing and maintaining multi-language pre-commit hooks
    serie # A rich git commit graph in your terminal, like magic
  ];

  programs.git = {
    enable = true;
    userName = "Felix Schausberger";
    delta = {enable = true;};
    extraConfig = {
      pull.rebase = true;
      credential.helper = "libsecret";
      core.editor = "${pkgs.helix}/bin/hx";
      safe.directory = "*";
    };
  };

  home.shellAliases = {
    amend = "git commit --amend";
    clone = "git clone";
    fetch = "git fetch";
    gap = "git add -p"; # --interactive
    gaa = "git add .";
    gcm = "git commit -m";
    gst = "git status";
    log = "git log --graph --abbrev-commit --all";
    main = "git checkout main";
    master = "git checkout master";
    # prune = "git filter-branch --index-filter \"git rm -f --cached --ignore-unmatch $1/*\" --prune-empty --tag-name-filter cat -- --all"
    pull = "git pull"; # --rebase origin main
    push = "git push"; # origin main
    rebase = "git rebase -i HEAD~2";
  };
}
