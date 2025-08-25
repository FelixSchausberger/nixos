{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      claude-code
      jq # For parsing JSON output in hooks
      # Development tools for hooks
      alejandra # Nix formatter
      deadnix # Dead code detection
      nixd # Nix LSP
      shellcheck # Shell script linter
    ];

    shellAliases = {
      claude = "claude --dangerously-skip-permissions";
    };
  };

  programs.gh.enable = true; # GitHub CLI tool.

  home.file.".claude/CLAUDE.md".text = ''
    # [CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory)

    "I, Claude, take you, CLAUDE.md to be my bible, my guide, to read and to obey from this session forward, through commits and reverts, for debugging, for analysing, in exceptions and compilation finished with (0) errors, to love, respect and to FOLLOW, till /clear us do part."
  '';

  xdg.configFile."claude-code/settings.json".text = builtins.toJSON {
    hasCompletedOnboarding = true;
    includeCoAuthoredBy = false;
    shiftEnterKeyBindingInstalled = true;
    theme = "dark";

    hooks = {
      "user-prompt-submit-hook" = {
        type = "command";
        command = "${pkgs.writeShellScript "smart-lint-hook" ''
          #!/bin/bash

          # Load configuration
          HOOK_CONFIG_FILE=".claude-hooks-config.sh"
          ENABLE_LINT_HOOK=true

          if [[ -f "$HOOK_CONFIG_FILE" ]]; then
            source "$HOOK_CONFIG_FILE"
          fi

          # Skip if disabled in config
          if [[ "$ENABLE_LINT_HOOK" != "true" ]]; then
            echo '{"status": "success", "message": "Linting hook disabled"}'
            exit 0
          fi

          # Run smart lint
          ${./smart-lint.sh}
        ''}";
      };

      "user-task-complete-hook" = {
        type = "command";
        command = "${pkgs.writeShellScript "smart-test-hook" ''
          #!/bin/bash

          # Load configuration
          HOOK_CONFIG_FILE=".claude-hooks-config.sh"
          ENABLE_TEST_HOOK=true

          if [[ -f "$HOOK_CONFIG_FILE" ]]; then
            source "$HOOK_CONFIG_FILE"
          fi

          # Skip if disabled in config
          if [[ "$ENABLE_TEST_HOOK" != "true" ]]; then
            echo '{"status": "success", "message": "Testing hook disabled"}'
            exit 0
          fi

          # Run smart test
          ${./smart-test.sh}
        ''}";
      };
    };

    # Declarative statusline configuration
    statusline = {
      command = "${pkgs.writeShellScript "claude-statusline" ''
        #!/bin/bash

        # Claude Code NixOS Developer Statusline
        # Focus on: Nix env, API usage (not Pro), context limits, detailed git changes
        # Styled to match Starship configuration

        # Read JSON input from stdin
        input=$(cat)

        # Extract values from JSON
        model_name=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Claude"')
        current_dir=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // "~"')
        project_dir=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.project_dir // ""')
        output_style=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.output_style.name // "default"')
        version=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.version // ""')
        session_id=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.session_id // ""')
        transcript_path=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.transcript_path // ""')

        # Detect if using API vs Pro subscription
        # This is a heuristic - API users typically have session costs that matter more
        is_api_user() {
            # Simple heuristic: if we have a very long session or specific pricing concerns
            # You can adjust this logic based on your actual usage patterns
            return 0  # For now, assume API user to show costs - you can modify this
        }

        # Nix Environment Detection
        get_nix_env_info() {
            local nix_info=""

            # Check for flake.nix
            if [[ -f "flake.nix" ]]; then
                nix_info="✨flake"
            # Check if in a nix-shell
            elif [[ -n "$IN_NIX_SHELL" ]]; then
                if [[ "$IN_NIX_SHELL" == "pure" ]]; then
                    nix_info="❄️pure-shell"
                else
                    nix_info="❄️nix-shell"
                fi
            # Check for shell.nix
            elif [[ -f "shell.nix" ]] || [[ -f "default.nix" ]]; then
                nix_info="❄️nix-env"
            # Check if we're in a devshell
            elif [[ -n "$DEVSHELL_ROOT" ]]; then
                nix_info="🛠️devshell"
            fi

            if [[ -n "$nix_info" ]]; then
                echo "\033[1;94m$nix_info\033[0m"
            fi
        }

        # Detailed Git Status (Starship style)
        get_git_status() {
            if ! ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
                return
            fi

            local branch=$(${pkgs.git}/bin/git branch --show-current 2>/dev/null)
            if [[ -z "$branch" ]]; then
                return
            fi

            local git_status=""

            # Get detailed status counts
            local staged=$(${pkgs.git}/bin/git diff --cached --name-only 2>/dev/null | wc -l)
            local modified=$(${pkgs.git}/bin/git diff --name-only 2>/dev/null | wc -l)
            local deleted=$(${pkgs.git}/bin/git status --porcelain 2>/dev/null | grep "^.D" | wc -l)
            local untracked=$(${pkgs.git}/bin/git status --porcelain 2>/dev/null | grep "^??" | wc -l)

            # Get ahead/behind info
            local ahead_behind=$(${pkgs.git}/bin/git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "0	0")
            local ahead=$(echo "$ahead_behind" | cut -f1)
            local behind=$(echo "$ahead_behind" | cut -f2)

            # Branch name with appropriate color
            if [[ $staged -gt 0 || $modified -gt 0 || $deleted -gt 0 || $untracked -gt 0 ]]; then
                git_status+="\033[1;91m$branch\033[0m"
            else
                git_status+="\033[1;92m$branch\033[0m"
            fi

            # Ahead/behind indicators (Starship style)
            if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
                git_status+=" \033[1;93m⇕⇡$ahead⇣$behind\033[0m"
            elif [[ $ahead -gt 0 ]]; then
                git_status+=" \033[1;93m⇡$ahead\033[0m"
            elif [[ $behind -gt 0 ]]; then
                git_status+=" \033[1;93m⇣$behind\033[0m"
            fi

            # File status indicators (Starship style)
            local changes=""
            if [[ $staged -gt 0 ]]; then
                changes+="\033[1;92m[++$staged]\033[0m"
            fi
            if [[ $modified -gt 0 ]]; then
                changes+="\033[1;93m!$modified\033[0m"
            fi
            if [[ $deleted -gt 0 ]]; then
                changes+="\033[1;91m-$deleted\033[0m"
            fi
            if [[ $untracked -gt 0 ]]; then
                changes+="\033[1;94m?$untracked\033[0m"
            fi

            if [[ -n "$changes" ]]; then
                git_status+=" $changes"
            fi

            echo "$git_status"
        }

        # Context & Usage Tracking
        get_usage_metrics() {
            local usage_info=""

            if [[ -f "$transcript_path" ]]; then
                # Context Progress: 0% = start of chat, 100% = context full/compact needed
                local file_size=$(stat -c%s "$transcript_path" 2>/dev/null || echo "0")
                local estimated_tokens=$((file_size / 3))  # ~3 chars per token

                # Context window: Sonnet 4 has ~200K tokens
                local context_limit=200000
                local context_progress=$(echo "scale=0; $estimated_tokens * 100 / $context_limit" | ${pkgs.bc}/bin/bc -l 2>/dev/null || echo "0")

                # Cap context at 100%
                if [[ $context_progress -gt 100 ]]; then
                    context_progress=100
                fi

                # Context progress with your exact color scheme
                if [[ $context_progress -ge 85 ]]; then
                    usage_info+="\033[1;91m''${context_progress}%\033[0m"
                elif [[ $context_progress -ge 70 ]]; then
                    usage_info+="\033[1;93m''${context_progress}%\033[0m"
                else
                    usage_info+="\033[1;92m''${context_progress}%\033[0m"
                fi

                # Global Usage: Track daily token usage
                local usage_file="$HOME/.claude-usage-$(date +%Y-%m-%d)"

                # Update global usage tracking
                if [[ -f "$usage_file" ]]; then
                    local previous_usage=$(cat "$usage_file" 2>/dev/null || echo "0")
                    local new_total=$((previous_usage + estimated_tokens / 100))  # Incremental update
                    echo "$new_total" > "$usage_file"
                else
                    echo "$((estimated_tokens / 100))" > "$usage_file"
                fi

                # Calculate global usage percentage
                local daily_limit=1000000  # Adjust based on your limits
                local daily_used=$(cat "$usage_file" 2>/dev/null || echo "0")
                local global_usage=$(echo "scale=0; $daily_used * 100 / $daily_limit" | ${pkgs.bc}/bin/bc -l 2>/dev/null || echo "0")

                # Cap at 100%
                if [[ $global_usage -gt 100 ]]; then
                    global_usage=100
                fi

                # Global usage with your exact color scheme
                if [[ $global_usage -ge 85 ]]; then
                    usage_info+=" \033[1;91m''${global_usage}%\033[0m"
                elif [[ $global_usage -ge 70 ]]; then
                    usage_info+=" \033[1;93m''${global_usage}%\033[0m"
                else
                    usage_info+=" \033[1;92m''${global_usage}%\033[0m"
                fi
            fi

            echo "$usage_info"
        }

        # Build the statusline
        nix_env=$(get_nix_env_info)
        git_info=$(get_git_status)
        usage_metrics=$(get_usage_metrics)
        dir_name=$(basename "$current_dir")

        # Start building status line
        status_line=""

        # Nix environment indicator (high priority for NixOS workflow)
        if [[ -n "$nix_env" ]]; then
            status_line+="$nix_env "
        fi

        # Directory name
        status_line+="\033[1;94m$dir_name\033[0m"

        # Git status with detailed breakdown
        if [[ -n "$git_info" ]]; then
            status_line+=" $git_info"
        fi

        # Usage metrics (context % + API costs if applicable)
        if [[ -n "$usage_metrics" ]]; then
            status_line+=" [$usage_metrics]"
        fi

        # Claude model
        status_line+=" \033[1;96m$model_name\033[0m"

        # Use printf with escape sequence interpretation to handle ANSI colors properly
        printf "%b\n" "$status_line"
      ''}";
    };
  };
}
