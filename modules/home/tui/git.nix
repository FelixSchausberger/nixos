{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo;
in {
  home = {
    file.".ssh/config".text = ''
      # Corporate Frequentis Git server
      Host git.frequentis.frq
          HostName git.frequentis.frq
          Port 7999
          User git
          IdentityFile ~/.ssh/id_ed25519

      # GitHub (primary - port 22)
      Host github.com
          HostName github.com
          Port 22
          User git
          IdentityFile ~/.ssh/id_ed25519

      # GitHub SSH over HTTPS (fallback when port 22 is blocked)
      Host github.com-443
          HostName ssh.github.com
          Port 443
          User git
          IdentityFile ~/.ssh/id_ed25519
    '';

    packages = with pkgs; [
      inputs.self.packages.${pkgs.system}.lumen # Instant AI Git Commit message, Git changes summary from the CLI
      lazygit # A simple terminal UI for git commands
      serie # A rich git commit graph in your terminal, like magic
      # graphite-cli # CLI that makes creating stacked git changes fast & intuitive
    ];

    # User-level nix configuration for GitHub access token
    activation.nixConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
      mkdir -p ~/.config/nix
      echo "access-tokens = github.com=$(cat ${config.sops.secrets."github/token".path})" > ~/.config/nix/nix.conf
    '';

    shellAliases = {
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
      rebase = "git rebase -i";
      show = "git show";
      undo = "git reset --soft HEAD~1";
      redo = "git reset --hard HEAD@{1}";
      ragequit = "sh -c 'git commit -am wip && shutdown -h now'";
      # https://junegunn.github.io/fzf/releases/0.63.0/
      gsearch =
        "git ls-files | fzf --style full --scheme path "
        + "--border --padding 1,2 "
        + "--ghost 'Search git files...' "
        + "--border-label ' Git Files ' --input-label ' Query ' --header-label ' File Type ' "
        + "--footer-label ' Hashes ' "
        + "--preview 'BAT_THEME=gruvbox-dark fzf-preview.sh {}' "
        + "--bind 'result:bg-transform-list-label:"
        + "if [[ -z \$FZF_QUERY ]]; then "
        + "echo \" \$FZF_MATCH_COUNT items \"; "
        + "else "
        + "echo \" \$FZF_MATCH_COUNT matches for [\$FZF_QUERY] \"; "
        + "fi' "
        + "--bind 'focus:bg-transform-preview-label:[[ -n {} ]] && printf \" Previewing [%s] \" {}' "
        + "--bind 'focus:+bg-transform-header:[[ -n {} ]] && file --brief {}' "
        + "--bind 'focus:+bg-transform-footer:"
        + "if [[ -n {} ]]; then "
        + "echo \"MD5:    \$(md5sum < {} | cut -d\" \" -f1)\"; "
        + "echo \"SHA1:   \$(sha1sum < {} | cut -d\" \" -f1)\"; "
        + "echo \"SHA256: \$(sha256sum < {} | cut -d\" \" -f1)\"; "
        + "fi' "
        + "--bind 'ctrl-r:change-list-label( Reloading... )+reload(sleep 0.5; git ls-files)' "
        + "--color 'border:#aaaaaa,label:#cccccc' "
        + "--color 'preview-border:#9999cc,preview-label:#ccccff' "
        + "--color 'list-border:#669966,list-label:#99cc99' "
        + "--color 'input-border:#996666,input-label:#ffcccc' "
        + "--color 'header-border:#6699cc,header-label:#99ccff' "
        + "--color 'footer:#ccbbaa,footer-border:#cc9966,footer-label:#cc9966'";
    };
  };

  programs.git = {
    enable = true;
    userName = personalInfo.name;
    userEmail = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
    delta = {enable = true;};
    extraConfig = {
      github.token = "${config.sops.secrets."github/token".path}";
      init.defaultBranch = "main";
      pull.rebase = true;
      credential.helper = "libsecret";
      core.editor = "${pkgs.helix}/bin/hx";
      safe.directory = "*";
      # Commit message template
      commit.template = "/per/etc/nixos/.gitmessage";
      # System-wide SSL certificate configuration for all HTTPS Git operations
      http.sslCAInfo = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

      # Corporate SSL certificate fix
      "http \"http://git.frequentis.frq/\"".sslVerify = false;
      "http \"https://git.frequentis.frq/\"".sslVerify = false;
      # GitHub authentication for Nix flake operations
      "credential \"https://github.com\"".helper = "!f() { echo username=token; echo password=$(cat ${config.sops.secrets."github/token".path}); }; f";
      "credential \"https://api.github.com\"".helper = "!f() { echo username=token; echo password=$(cat ${config.sops.secrets."github/token".path}); }; f";
    };
  };

  sops.secrets = {
    "github/token" = {};
  };
}
