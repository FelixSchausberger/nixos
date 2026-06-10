{inputs, ...}: {
  programs.yazi = {
    plugins = {
      chmod = "${inputs.yazi-plugins}/chmod.yazi";
    };

    keymap.manager.prepend_keymap = [
      {
        on = ["c" "m"];
        run = "plugin chmod";
        desc = "Chmod on selected files";
      }
    ];
  };
}
