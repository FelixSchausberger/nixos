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

      # === CRITICAL SAFETY: Early PATH Guard ===
      # Ensure PATH is set before loading plugins or initializing shell
      # This prevents lockouts when PATH is not initialized by the system
      if not test -n "$PATH"
        set -gx PATH /run/current-system/sw/bin /usr/bin /bin
      end

      # WSL-specific PATH validation - ensure core utilities are accessible
      # This addresses the root cause of the fish plugin failures
      if not command -v ls >/dev/null 2>&1; or not command -v sort >/dev/null 2>&1
        # PATH exists but is incomplete - prepend system paths
        set -gx PATH /run/current-system/sw/bin $PATH
      end

      # Verify minimum viable environment - fall back to bash if fish is broken
      if not command -v fish >/dev/null 2>&1
        echo "🚨 CRITICAL: Fish shell environment broken, falling back to bash"
        exec /run/current-system/sw/bin/bash --noprofile --norc
      end

      # === EMERGENCY ESCAPE HATCH ===
      # Check for emergency mode bypass file BEFORE any other initialization
      # Create this file to disable all auto-start and integrations:
      #   touch ~/.config/fish/EMERGENCY_MODE_ENABLED
      if test -f ~/.config/fish/EMERGENCY_MODE_ENABLED
        echo "🚨 EMERGENCY MODE BYPASS ACTIVE"
        echo "   All auto-start features disabled"
        echo "   All shell integrations disabled"
        echo "   To restore normal operation:"
        echo "   rm ~/.config/fish/EMERGENCY_MODE_ENABLED"
        echo ""
        # Do NOT exit - continue with minimal shell to avoid WSL lockout
        return 0
      end

      # Enable zellij auto-start by default (can be disabled with ZELLIJ_AUTO_START=0)
      set -gx ZELLIJ_AUTO_START 1

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
            # Check for force flag
            if test "$arg" = "-f"; or test "$arg" = "--force"
              set force_mode true
            # Strip common rm flags that rip doesn't support
            else if test "$arg" = "-r"; or test "$arg" = "-R"; or test "$arg" = "--recursive"
              # Skip recursive flags - rip handles directories automatically
              continue
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


      # === PRE-FLIGHT SAFETY CHECKS ===
      # Comprehensive validation before enabling any auto-start features
      function __zellij_preflight_check
        # Check 1: PATH is set and functional
        if not test -n "$PATH"
          return 1
        end

        # Check 2: Core commands available (critical for WSL)
        if not command -v fish >/dev/null 2>&1
          return 1
        end
        if not command -v ls >/dev/null 2>&1
          return 1
        end

        # Check 3: WSL root shell detection - skip auto-start for root
        if test (id -u) -eq 0
          return 1
        end

        # Check 4: Zellij binary exists and is executable
        if not command -v zellij >/dev/null 2>&1
          return 1
        end

        # Check 5: Zellij configuration is valid
        if not zellij setup --check >/dev/null 2>&1
          return 1
        end

        return 0
      end

      # === SAFE ZELLIJ AUTO-START ===
      # Using official Zellij integration method - NEVER use 'exec' for multiplexers
      # This prevents shell lockouts by providing automatic fallback on failure
      #
      # To enable: set -gx ZELLIJ_AUTO_START 1
      # To disable: set -e ZELLIJ_AUTO_START
      #
      # Official documentation: https://zellij.dev/documentation/integration.html
      if status is-interactive; and set -q ZELLIJ_AUTO_START; and not __emergency_check
        # Run pre-flight checks before attempting auto-start
        if __zellij_preflight_check
          # Use official Zellij auto-start method (safe, with fallback)
          eval (zellij setup --generate-auto-start fish | string collect)
        else
          echo "⚠️  Zellij pre-flight checks failed - starting normal fish shell"
          echo "   To enable auto-start, ensure zellij is properly configured"
        end
      end
    '';
  };
}
