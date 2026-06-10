{inputs, ...}: {
  programs.yazi = {
    plugins = {
      git = "${inputs.yazi-plugins}/git.yazi";
    };

    settings.plugin.prepend_fetchers = [
      {
        id = "git";
        name = "*";
        run = "git";
      }
      {
        id = "git";
        name = "*/";
        run = "git";
      }
    ];

    initLua = ''
      require("git"):setup()
    '';
  };
}
