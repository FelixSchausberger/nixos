{pkgs, ...}: {
  home.packages = with pkgs; [
    bash-completion
  ];

  programs.bash = {
    enable = true;
    package = pkgs.bashInteractive;

    # Shell aliases
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      grep = "grep --color=auto";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    # History configuration
    historyControl = ["ignoredups" "ignorespace"];
    historyIgnore = ["ls" "cd" "exit"];
    historySize = 10000;
    historyFileSize = 20000;

    # Bash-specific initialization
    bashrcExtra = ''
      # Enable bash completion
      if [ -f ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh ]; then
        source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      fi

      # Custom functions
      mkcd() {
        mkdir -p "$1" && cd "$1"
      }

      extract() {
        if [ -f "$1" ]; then
          case "$1" in
            *.tar.bz2)   tar xjf "$1"    ;;
            *.tar.gz)    tar xzf "$1"    ;;
            *.bz2)       bunzip2 "$1"    ;;
            *.rar)       unrar x "$1"    ;;
            *.gz)        gunzip "$1"     ;;
            *.tar)       tar xf "$1"     ;;
            *.tbz2)      tar xjf "$1"    ;;
            *.tgz)       tar xzf "$1"    ;;
            *.zip)       unzip "$1"      ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1"       ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
          esac
        else
          echo "'$1' is not a valid file"
        fi
      }

      # Better directory navigation
      shopt -s autocd 2>/dev/null || true        # Change to directory by typing name
      shopt -s cdspell 2>/dev/null || true       # Autocorrect typos in path names
      shopt -s dirspell 2>/dev/null || true      # Autocorrect typos in directory names
      shopt -s checkwinsize 2>/dev/null || true  # Check window size after each command
      shopt -s histappend 2>/dev/null || true    # Append to history file, don't overwrite

      # Enable programmable completion
      shopt -s progcomp 2>/dev/null || true

      # If fish shell is available and not already running, exec to fish
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
        if command -v fish &> /dev/null; then
          shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
          exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
        fi
      fi
    '';

    # Profile initialization (runs for login shells)
    profileExtra = ''
      # Add local bin to PATH if it exists
      if [ -d "$HOME/.local/bin" ]; then
        PATH="$HOME/.local/bin:$PATH"
      fi
    '';
  };
}
