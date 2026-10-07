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
    extraFiles."lua/config/clipboard.lua".source = ./lua/config/clipboard.lua;
    extraFiles."lua/config/opencode_server.lua".source = ./lua/config/opencode_server.lua;
    extraFiles."lua/config/scooter.lua".source = ./lua/config/scooter.lua;
    extraFiles."lua/config/title.lua".source = ./lua/config/title.lua;

    extraConfigLua = ''
      require("config.clipboard")
      require("config.scooter")
      require("config.title")
    '';
  };
}
