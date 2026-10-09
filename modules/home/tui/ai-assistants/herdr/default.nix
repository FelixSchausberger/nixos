{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  options.tui.herdr = {
    enable =
      lib.mkEnableOption "herdr terminal multiplexer for AI agents"
      // {
        default = true;
      };
  };

  config = lib.mkIf config.tui.herdr.enable {
    home.packages = [pkgs.herdr];

    # herdr's plugin registry is imperative state (plugins.json) keyed by the
    # linked source path, so it cannot be a read-only Home Manager file. Link
    # the TTT editor plugin out of the ttt flake input at activation; relinking
    # is idempotent and repoints the plugin after a ttt bump. The herdr binary
    # is called by absolute path because activation runs before the new
    # profile is on PATH; XDG_CONFIG_HOME is pinned so the link lands in the
    # same config root as xdg.configFile below.
    home.activation.linkTttHerdrPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
      XDG_CONFIG_HOME=${config.xdg.configHome} \
        ${pkgs.herdr}/bin/herdr plugin link ${inputs.ttt}/herdr-plugin \
        >/dev/null 2>&1 || true
    '';

    # herdr ships a built-in catppuccin theme, so it needs no generated palette
    # to match the fleet. TTT opens as a tab in the current workspace through
    # its plugin action; prefix+e is already herdr's edit_scrollback default,
    # so the editor takes prefix+shift+e.
    xdg.configFile."herdr/config.toml".text = ''
      [theme]
      name = "catppuccin"

      [[keys.command]]
      key = "prefix+shift+e"
      type = "plugin_action"
      command = "ttt.editor.open"
      description = "Open TTT editor"
    '';
  };
}
