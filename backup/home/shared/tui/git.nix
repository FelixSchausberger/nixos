# Defines the base Git configuration for Home Manager, including common packages and aliases.
{ inputs, pkgs, ... }: {
  home.packages = with pkgs; [
    inputs.self.packages.${pkgs.system}.lumen
    pre-commit
    serie
  ];

  programs.git = {
    enable = true;
    userName = "Felix Schausberger";
    delta.enable = true;
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
    gap = "git add -p";
    gaa = "git add .";
    gcm = "git commit -m";
    gst = "git status";
    log = "git log --graph --abbrev-commit --all";
    main = "git checkout main";
    master = "git checkout master";
    pull = "git pull";
    push = "git push";
    rebase = "git rebase -i";
    show = "git show";
  };
}
