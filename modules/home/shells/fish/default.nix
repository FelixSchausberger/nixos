{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./functions
    ./plugins.nix
  ];

  home.packages = with pkgs; [
    grc # A generic text colouriser
  ];

  programs.fish = {
    enable = true;
    shellAliases = {
      # Fix Zed editor binary conflict with ZFS daemon
      zed = "zeditor";
    };
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # Emergency shell functions - NixOS integrated
      ${(import ../emergency-functions.nix {inherit lib;}).emergencyShellFunctions.fish}

      function emergency-reset
        string pad --center --width 60 "🔄 Resetting shell to safe state"
        if emergency-mode-check >/dev/null 2>&1
          echo "⚠️  System is in emergency mode - use 'systemctl default' to exit"
        else
          echo "✅ Emergency mode not active - restarting fish in safe mode..."
          exec fish --no-config
        end
      end

      # Emergency mode detection using shared function
      if __emergency_check
        echo "🚨 Emergency shell mode active - all integrations disabled"
        echo "   Use 'emergency-help' for recovery options"
        echo "   Use 'emergency-off' to disable, then restart shell"
      else
        # Simple config function - replacement for complex nx_config
        function config --description "Open NixOS configuration directory"
          set -l config_dir "/per/etc/nixos"
          if not test -d "$config_dir" -o not test -f "$config_dir/flake.nix"
            echo "⚠️  No NixOS configuration found at $config_dir"
            return 1
          end

          set -l original_dir $PWD
          cd $config_dir
          yazi
          cd $original_dir
        end

        # Smart rm function - safe by default with clear messaging
        function rm --description "Safe rm with rip (use rm -f for force)"
          # Check if this is a force operation
          set -l force_mode false
          set -l filtered_args

          for arg in $argv
            if test "$arg" = "-f" -o "$arg" = "--force"
              set force_mode true
            else
              set filtered_args $filtered_args $arg
            end
          end

          # Check if we're in an interactive shell and not in a script context
          set -l is_interactive false
          if status is-interactive
            # Additional check: not being called from a script
            if not set -q BASH_EXECUTION_STRING; and not set -q ZSH_EXECUTION_STRING
              set is_interactive true
            end
          end

          if test $force_mode = true
            # Force mode: use real rm
            if test $is_interactive = true
              string pad --center --width 60 "🔥 Using force delete (real rm)"
            end
            command rm $argv
          else if test $is_interactive = true
            # Interactive mode: use safe rip with message
            string pad --center --width 60 "🛡️  Using safe delete (rip)"
            echo "   Files moved to graveyard - use 'rm -f' for permanent deletion"
            rip --graveyard "/per/home/"(whoami)"/.local/share/graveyard" $filtered_args
          else
            # Script mode: use real rm silently to avoid breaking automation
            command rm $argv
          end
        end
        # Safe direnv initialization with enhanced error handling
        if command -v direnv >/dev/null 2>&1
          if direnv --help >/dev/null 2>&1
            if not direnv hook fish | source 2>/dev/null
              echo "⚠️  direnv hook failed to load - continuing without direnv integration"
            end
          else
            echo "⚠️  direnv found but not working properly - skipping integration"
          end
        end

        # Safe jujutsu completion with enhanced error handling (commented for now)
        # if command -v jj >/dev/null 2>&1
        #   if jj --help >/dev/null 2>&1
        #     if not COMPLETE=fish jj | source 2>/dev/null
        #       echo "⚠️  jj completions failed to load - continuing without jj completions"
        #     end
        #   end
        # end
      end


      # Optional auto-start zellij - now opt-in via environment variable
      # Set ZELLIJ_AUTO_START=1 to enable automatic zellij startup
      # Enhanced WSL compatibility with multiple detection methods
      if status is-interactive; and not set -q ZELLIJ; and set -q ZELLIJ_AUTO_START; and not __emergency_check
        # Check multiple conditions to prevent nested sessions
        set -l is_nested false

        # Check TERM_PROGRAM (works in most terminals)
        if string match -q "*zellij*" "$TERM_PROGRAM"
          set is_nested true
        end

        # Check if we're in SSH (prevent auto-start in SSH sessions)
        if set -q SSH_CLIENT; or set -q SSH_TTY; or set -q SSH_CONNECTION
          set is_nested true
        end

        # Check if we're being sourced by another script (prevent issues)
        if string match -q "*source*" "$_"
          set is_nested true
        end

        # Check if parent process is already zellij (backup method)
        if command -v pgrep >/dev/null 2>&1
          if pgrep -P (echo $fish_pid) zellij >/dev/null 2>&1
            set is_nested true
          end
        end

        # Special case: Skip auto-start in Claude Code terminal context to prevent TTY issues
        if string match -q "*code*" "$TERM_PROGRAM"; or string match -q "*vscode*" "$TERM_PROGRAM"
          set is_nested true
        end

        # If no nested session detected, start zellij with fallback
        if not test $is_nested = true
          string pad --center --width 60 "🚀 Starting Zellij"
          # Safety check: ensure zellij binary exists and configuration is valid
          if command -v zellij >/dev/null 2>&1
            # Validate zellij configuration before attempting to start
            if zellij --help >/dev/null 2>&1; and zellij setup --check >/dev/null 2>&1
              # Try to attach to existing session first, then create new with fallback
              if not zellij attach dev 2>/dev/null
                if not zellij attach -c dev 2>/dev/null
                  # Final fallback: start with default layout
                  # Add timeout safety mechanism to prevent hanging (if timeout available)
                  if command -v timeout >/dev/null 2>&1
                    if timeout 5s zellij --version >/dev/null 2>&1
                      exec zellij
                    else
                      echo "⚠️  Zellij startup test failed - continuing with regular shell"
                      echo "   Check zellij configuration: zellij setup --check"
                      echo "   You can manually start zellij with: zellij"
                    end
                  else
                    # No timeout command available, proceed carefully
                    echo "🔄 Starting zellij (no timeout available for safety check)..."
                    exec zellij
                  end
                end
              end
            else
              echo "⚠️  Zellij configuration validation failed - continuing with regular shell"
              echo "   Check zellij configuration: zellij setup --check"
              echo "   You can manually start zellij with: zellij"
            end
          else
            echo "⚠️  Zellij not found - continuing with regular Fish shell"
            echo "   Install zellij if you want terminal multiplexing"
          end
        else
          string pad --center --width 60 "ℹ️  Zellij auto-start skipped"
          echo "   Nested session detected - to start manually: zellij"
        end
      else
        # Auto-start is disabled - provide helpful information
        if status is-interactive; and not set -q ZELLIJ; and not __emergency_check
          string pad --center --width 60 "ℹ️  Zellij auto-start disabled"
          echo "   To enable: export ZELLIJ_AUTO_START=1"
          echo "   To start manually: zellij"
        end
      end
    '';
  };
}
