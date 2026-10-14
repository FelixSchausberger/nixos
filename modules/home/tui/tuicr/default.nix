{
  config,
  lib,
  pkgs,
  ...
}: {
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
    # hide every other scope.
    #
    # prefix+shift+c stands in for the review mnemonic: herdr already binds
    # reload_config to prefix+shift+r, and takes r for resize_mode too.
    tui.herdr.commandKeys = lib.mkAfter [
      {
        key = "prefix+shift+c";
        type = "popup";
        command = "tuicr";
        description = "Review changes in tuicr";
        width = "95%";
        height = "95%";
      }
    ];
  };
}
