{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo;
in {
  home = {
    # Base SSH config managed by Home Manager (declarative)
    file.".ssh/config.d/base.conf".text = ''
      # Corporate Frequentis Git server
      Host git.frequentis.frq
          HostName git.frequentis.frq
          Port 7999
          User git
          IdentityFile ~/.ssh/id_ed25519

      # GitHub (using port 443 due to corporate firewall)
      Host github.com
          HostName ssh.github.com
          Port 443
          User git
          IdentityFile ~/.ssh/id_ed25519
    '';

    packages = with pkgs; [
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.lumen # Instant AI Git Commit message, Git changes summary from the CLI
      lazygit # A simple terminal UI for git commands
      serie # A rich git commit graph in your terminal, like magic
      # graphite-cli # CLI that makes creating stacked git changes fast & intuitive
    ];

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
    settings = {
      user = {
        inherit (personalInfo) name;
        email = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
      };
      github.token = "${config.sops.secrets."github/token".path}";
      init.defaultBranch = "main";
      pull.rebase = true;
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

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # SSH config setup for hybrid declarative/imperative management
  # Create main config with Include directive to base config, allowing lazyssh to add entries
  home.activation.sshConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
        ssh_config="$HOME/.ssh/config"
        ssh_config_dir="$HOME/.ssh/config.d"

        # Ensure config.d directory exists
        $DRY_RUN_CMD mkdir -p "$ssh_config_dir"
        $DRY_RUN_CMD chmod 700 "$ssh_config_dir"

        # Create main SSH config with Include directive if it doesn't exist or is a symlink
        # If it's a regular file, preserve it (lazyssh may have added entries)
        if [[ ! -f "$ssh_config" ]] || [[ -L "$ssh_config" ]]; then
          $DRY_RUN_CMD cat > "$ssh_config" <<'EOF'
    # Base configuration (managed by Home Manager)
    Include ~/.ssh/config.d/base.conf

    # Lazyssh-managed servers will be added below this line
    # All entries below are imperative and persisted via impermanence

    EOF
          $DRY_RUN_CMD chmod 600 "$ssh_config"
        else
          # Config exists as regular file - check if Include directive is present
          if ! grep -q "Include ~/.ssh/config.d/base.conf" "$ssh_config"; then
            # Prepend Include directive to existing config
            $DRY_RUN_CMD cat > "$ssh_config.tmp" <<'EOF'
    # Base configuration (managed by Home Manager)
    Include ~/.ssh/config.d/base.conf

    EOF
            $DRY_RUN_CMD cat "$ssh_config" >> "$ssh_config.tmp"
            $DRY_RUN_CMD mv "$ssh_config.tmp" "$ssh_config"
            $DRY_RUN_CMD chmod 600 "$ssh_config"
          fi
        fi
  '';

  # User-level nix configuration for GitHub access token
  # Note: Cannot use xdg.configFile with sops secrets as the file content is only available at activation time
  # Using home.activation to read the secret file at runtime
  home.activation.nixConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.config/nix
    if [[ -f ${config.sops.secrets."github/token".path} ]]; then
      token=$(cat ${config.sops.secrets."github/token".path})
      echo "access-tokens = github.com=$token" > $HOME/.config/nix/nix.conf
    else
      echo "Warning: GitHub token file not found at ${config.sops.secrets."github/token".path}" >&2
    fi
  '';

  sops.secrets = {
    "github/token" = {};
  };
}
