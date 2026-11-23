{
  config,
  lib,
  pkgs,
  ...
}: let
  # Herdr launches a popup in the focused pane shell's cwd, and a Rookery seat
  # keeps that shell at the primary checkout while the agent process runs in
  # its jj workspace, so bare tuicr would review the wrong repository. The
  # wrapper changes to the pane's foreground process cwd before starting the
  # TUI and still leaves tuicr's own selector to choose the scope.
  tuicrHerdrOpen = pkgs.writeShellApplication {
    name = "tuicr-herdr-open";
    runtimeInputs = [pkgs.herdr pkgs.jq];
    text = ''
      set -euo pipefail

      herdr_bin="''${HERDR_BIN_PATH:-herdr}"
      pane="''${HERDR_ACTIVE_PANE_ID:-}"
      if [ -n "$pane" ]; then
        target="$("$herdr_bin" pane get "$pane" \
          | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty')"
        if [ -n "$target" ] && [ -d "$target" ]; then
          cd "$target"
        fi
      fi
      exec ${pkgs.tuicr}/bin/tuicr
    '';
  };
in {
  options.tui.tuicr = {
    enable =
      lib.mkEnableOption "tuicr code review TUI"
      // {
        default = true;
      };
  };

  config = lib.mkIf config.tui.tuicr.enable {
    home.packages = [pkgs.tuicr];

    # tuicr bundles catppuccin-mocha, so the theme matches the fleet without a
    # generated palette; unlike TTT it ships the palette itself. `editor` is
    # deliberately unset: tuicr's built-in default is a literal `nvim`, which
    # would bypass the fleet's $EDITOR policy (nvedit in editors/default.nix);
    # unset inherits that variable instead. comment_vim restores modal editing
    # in the review comment box.
    xdg.configFile."tuicr/config.toml".text = ''
      theme = "catppuccin-mocha"
      comment_vim = true
    '';

    # Bare tuicr opens its own target selector, where worktree changes, commit
    # ranges, forge PRs and saved sessions are chosen; pinning -w here would
    # hide every other scope. The wrapper only fixes the starting directory.
    #
    # prefix+shift+c stands in for the review mnemonic: herdr already binds
    # reload_config to prefix+shift+r, and takes r for resize_mode too.
    tui.herdr.commandKeys = lib.mkAfter [
      {
        key = "prefix+shift+c";
        type = "popup";
        command = "${tuicrHerdrOpen}/bin/tuicr-herdr-open";
        description = "Review changes in tuicr";
        width = "95%";
        height = "95%";
      }
    ];
  };
}
