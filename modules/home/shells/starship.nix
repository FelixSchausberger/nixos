{
  pkgs,
  inputs,
  ...
}: {
  programs.bash = {
    enable = true;

    bashrcExtra = ''
      # Safe starship initialization with emergency mode support
      if ! emergency-mode-check >/dev/null 2>&1; then
        # Only initialize starship in interactive shells with proper terminal
        if [[ $- == *i* ]] && [[ "$TERM" != "dumb" ]]; then
          if command -v starship >/dev/null 2>&1; then
            if starship --help >/dev/null 2>&1; then
              eval "$(starship init bash)"
            else
              echo "⚠️  starship found but not working properly - using fallback prompt"
              PS1='\u@\h:\w\$ '
            fi
          else
            echo "⚠️  starship not found - using fallback prompt"
            PS1='\u@\h:\w\$ '
          fi
        fi
      else
        echo "🚨 Emergency mode active - starship disabled"
        PS1='[EMERGENCY] \u@\h:\w\$ '
      fi
    '';
  };

  programs.starship = {
    enable = true;

    # The TransientPrompt feature of Starship replaces previous prompts with a custom string.
    # This is only a valid option for the Fish shell.
    # enableTransience = true;

    # https://starship.rs/config/#prompt
    settings = {
      # Disable built-in git modules (replaced with conditional custom modules)
      git_branch.disabled = true;
      git_commit.disabled = true;
      git_state.disabled = true;
      git_metrics.disabled = true;
      git_status.disabled = true;

      # Custom modules for git and jj integration
      custom = {
        # Conditional git modules - only show when NOT in a jj repo
        # Uses starship's built-in modules via custom wrapper
        git_branch = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_branch";
          shell = ["sh" "--norc"];
          description = "Show git branch only when not in jj repo";
        };

        git_status = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_status";
          shell = ["sh" "--norc"];
          description = "Show git status only when not in jj repo";
        };

        # starship-jj integration (upstream tool)
        # Uses jj-cli crate for better performance than multiple jj invocations
        # Displays bookmarks, commit state, and file change metrics
        # Always runs (will be empty in non-jj repos)
        jj = {
          command = "prompt";
          format = "$output";
          ignore_timeout = true;
          shell = [
            "${inputs.self.packages.${pkgs.hostPlatform.system}.starship-jj}/bin/starship-jj"
            "--ignore-working-copy"
            "starship"
          ];
          use_stdin = false;
          when = true;
        };
      };
    };
  };
}
