# modules/home/tui/git.nix
# Base shared Git configuration for Home Manager.
{ pkgs, config, inputs, ... }: { # Assuming inputs might be needed for lumen
  home.packages = with pkgs; [
    # Assuming lumen is accessible via pkgs or config.flake.inputs.self.packages...
    # If using inputs.self directly: inputs.self.packages.${pkgs.system}.lumen
    # For now, let's list it and it might need adjustment if 'inputs.self' isn't passed.
    # Consider making lumen a direct pkgs attribute via an overlay if not already.
    # For simplicity in this step, if lumen is problematic, the user can add it manually later.
    # lumen 
    pre-commit
    serie
  ];

  programs.git = {
    enable = true;
    userName = "Felix Schausberger"; # Default username
    delta.enable = true;
    extraConfig = {
      pull.rebase = true;
      credential.helper = "libsecret";
      core.editor = pkgs.lib.getExe pkgs.helix; # Ensures we get the binary path
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
