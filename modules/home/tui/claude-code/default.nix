{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      claude-code
      bun # For running ccusage with bunx
      nodejs # Alternative runtime for ccusage
      jq # For parsing ccusage JSON output in hooks
      # Development tools for hooks
      alejandra # Nix formatter
      deadnix # Dead code detection
      nixd # Nix LSP
      shellcheck # Shell script linter
    ];

    shellAliases = {
      # claude = "npx ccusage statusline && claude --dangerously-skip-permissions";
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

    statusLine = {
      type = "command";
      command = "${pkgs.writeShellScript "claude-statusline" ''
        #!/bin/bash
        input=$(cat)
        model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name')
        ccusage=$(${pkgs.bun}/bin/bunx ccusage statusline 2>/dev/null || echo "📊 Usage data unavailable")
        printf "%s | %s" "$model" "$ccusage"
      ''}";
    };

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
  };
}
