{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      claude-code
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

  xdg.configFile."claude-code/settings.json".text = ''
    "hasCompletedOnboarding": true,
    "includeCoAuthoredBy": false,
    "shiftEnterKeyBindingInstalled": true,
    "theme": "dark"
  '';
}
