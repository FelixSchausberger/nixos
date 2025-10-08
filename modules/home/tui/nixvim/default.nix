{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
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

    # Extra plugins
    extraPlugins = with pkgs.vimPlugins; [
      claude-code-nvim
    ];

    # Configure claude-code.nvim
    extraConfigLua = ''
      require('claude-code').setup({
        -- Default configuration
        -- See: https://github.com/greggh/claude-code.nvim for options
      })
    '';
  };
}
