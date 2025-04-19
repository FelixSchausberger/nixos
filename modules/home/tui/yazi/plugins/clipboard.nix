{inputs, ...}: {
  home.file.".config/yazi/plugins/clipboard" = {
    source = inputs.yazi-clipboard;
    recursive = true;
  };

  programs.yazi = {
    keymap.manager.prepend_keymap = [
      {
        on = ["C" "y"];
        run = ["plugin clipboard"];
        desc = "Copy files to clipboard";
      }
    ];
  };
}
