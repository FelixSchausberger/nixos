{inputs, ...}: {
  programs.yazi = {
    # `clipboard` is a built-in plugin name; the loader checks its own cache
    # before the config directory, so a user plugin with that name never runs.
    plugins.clip = "${inputs.yazi-clipboard}";

    keymap.mgr.prepend_keymap = [
      {
        on = ["C" "y"];
        run = "plugin clip";
        desc = "Copy files to clipboard";
      }
    ];
  };
}
