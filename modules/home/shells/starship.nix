{
  programs.bash = {
    enable = true;

    bashrcExtra = ''
      # Only initialize starship in interactive shells with proper terminal
      if [[ $- == *i* ]] && [[ "$TERM" != "dumb" ]]; then
        eval "$(starship init bash)"
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
      # add_newline = false;
      command_timeout = 1000; # Timeout for commands executed by starship (in milliseconds)

      git_status = {
        ahead = "⇡($count)";
        diverged = "⇕⇡($ahead_count)⇣($behind_count)";
        behind = "⇣($count)";
        modified = "!($count)";
        staged = "[++($count)](green)";
      };

      # Custom JJ (Jujutsu) module until native support is available
      # Shows current change ID and working copy status
      custom.jj = {
        command = "jj log -r @ --no-graph --color never -T 'change_id.shortest(8)'";
        when = "jj root";
        format = "on [$output]($style) ";
        style = "bold purple";
        symbol = "jj";
        description = "Show current Jujutsu change ID";
      };

      # Add custom JJ status indicator
      custom.jj_status = {
        command = ''
          if jj status --no-pager 2>/dev/null | grep -q "Working copy changes:"; then
            echo "●"
          else
            echo "○"
          fi
        '';
        when = "jj root";
        format = "[$output]($style)";
        style = "bold yellow";
        description = "Show if working copy has changes";
      };
    };
  };
}
