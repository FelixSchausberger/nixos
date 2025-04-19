{inputs, ...}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./autocommands.nix
    ./options.nix
    ./plugins
  ];

  home.shellAliases.v = "nvim";

  # https://nix-community.github.io/nixvim/search/
  programs.nixvim = {
    enable = true;
    # defaultEditor = true;

    # colorschemes.gruvbox.enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    luaLoader.enable = true;
  };
}
