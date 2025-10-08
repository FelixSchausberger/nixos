{
  pkgs,
  lib,
  ...
}: {
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

      # Emergency shell functions - NixOS integrated
      ${(import ./emergency-functions.nix {inherit lib;}).emergencyShellFunctions.bash}

      # Smart rm function - safe by default with clear messaging
      rm() {
        local force_mode=false
        local filtered_args=()

        # Parse arguments for force flags
        for arg in "$@"; do
          if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
            force_mode=true
          else
            filtered_args+=("$arg")
          fi
        done

        # Check if we're in an interactive shell and not in a script context
        local is_interactive=false
        if [[ $- == *i* ]] && [[ -z "$BASH_EXECUTION_STRING" ]]; then
          is_interactive=true
        fi

        if [[ "$force_mode" == true ]]; then
          # Force mode: use real rm
          if [[ "$is_interactive" == true ]]; then
            echo "🔥 Using force delete (real rm)"
          fi
          command rm "$@"
        elif [[ "$is_interactive" == true ]]; then
          # Interactive mode: use safe rip with message
          echo "🛡️  Using safe delete (rip) - files moved to graveyard"
          echo "   Use 'rm -f' for permanent deletion"
          rip --graveyard "/per/home/$(whoami)/.local/share/graveyard" "''${filtered_args[@]}"
        else
          # Script mode: use real rm silently to avoid breaking automation
          command rm "$@"
        fi
      }

      # Emergency mode detection using shared function
      if __emergency_check; then
        echo "🚨 Emergency shell mode active - staying in bash"
        echo "   Type 'emergency-help' for recovery options"
        echo "   Type 'emergency-off' to disable emergency mode"
        PS1='[EMERGENCY] \u@\h:\w\$ '
      else
        # Enhanced shell transition with safety guards
        # Only transition to fish if we're not already in fish and conditions are safe
        # Skip transition if running under systemd service or Home Manager activation
        if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm 2>/dev/null || echo "unknown") != "fish" &&
              -z ''${BASH_EXECUTION_STRING} &&
              -z "$SYSTEMD_EXEC_PID" &&
              "$0" != *"hm-setup-env"* ]]; then
          # Safety check 1: Ensure fish is available and functional
          if command -v fish &> /dev/null; then
            # Check if timeout command is available for safety checks
            if command -v timeout &> /dev/null; then
              # Safety check 2: Test fish functionality with timeout
              if timeout 10s fish --version &> /dev/null; then
                # Safety check 3: Verify fish can start without hanging
                if timeout 5s fish -c 'exit' &> /dev/null; then
                  # Safety check 4: Test fish configuration validity
                  if timeout 5s fish -c 'set -l test_var success; test "$test_var" = success' &> /dev/null; then
                    shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
                    echo "🐟 Transitioning to fish shell..."
                    exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
                  else
                    echo "⚠️  fish configuration test failed - staying in bash"
                    echo "   You can manually start fish with: fish --no-config"
                    PS1='\u@\h:\w\$ '
                  fi
                else
                  echo "⚠️  fish startup test failed - staying in bash"
                  echo "   You can manually start fish with: fish"
                  PS1='\u@\h:\w\$ '
                fi
              else
                echo "⚠️  fish version check failed or timed out - staying in bash"
                echo "   You can manually start fish with: fish"
                PS1='\u@\h:\w\$ '
              fi
            else
              # No timeout available - do basic tests without timeouts
              if fish --version &> /dev/null; then
                if fish -c 'exit' &> /dev/null; then
                  shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
                  echo "🐟 Transitioning to fish shell (no timeout safety available)..."
                  exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
                else
                  echo "⚠️  fish basic test failed - staying in bash"
                  echo "   You can manually start fish with: fish"
                  PS1='\u@\h:\w\$ '
                fi
              else
                echo "⚠️  fish version check failed - staying in bash"
                echo "   You can manually start fish with: fish"
                PS1='\u@\h:\w\$ '
              fi
            fi
          else
            echo "⚠️  fish not found - staying in bash"
            PS1='\u@\h:\w\$ '
          fi
        else
          # Already in fish or in non-interactive mode
          PS1='\u@\h:\w\$ '
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
