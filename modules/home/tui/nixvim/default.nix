{inputs, ...}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./autocommands.nix
    ./keymaps.nix
    ./options.nix
    ./plugins
  ];

  # Live-config aliases (viAlias/vimAlias/vimdiffAlias below cover vim/vi).
  home.shellAliases.v = "nvim";

  # https://nix-community.github.io/nixvim/search/
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    luaLoader.enable = true;

    # Bespoke logic stays in real Lua files under lua/, loaded here.
    extraFiles."lua/config/title.lua".source = ./lua/config/title.lua;

    extraConfigLua = ''
      require("config.title")
    '';
  };
}
