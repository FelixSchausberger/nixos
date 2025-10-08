{inputs, ...}: {
  home.file.".config/yazi/plugins/starship" = {
    source = inputs.yazi-starship;
    recursive = true;
  };

  programs.yazi = {
    initLua = ''
      require("starship"):setup()
    '';
  };
}
