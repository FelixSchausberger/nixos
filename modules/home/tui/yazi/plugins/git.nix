{inputs, ...}: {
  programs.yazi = {
    plugins = {
      git = "${inputs.yazi-plugins}/git.yazi";
    };

    # Schema per git.yazi README at the pinned revision; yazi 26.5.6 renamed
    # fetcher `id` to `group` and `name` to `url`
    settings.plugin.prepend_fetchers = [
      {
        url = "*";
        run = "git";
        group = "git";
      }
      {
        url = "*/";
        run = "git";
        group = "git";
      }
    ];

    initLua = ''
      require("git"):setup()
    '';
  };
}
