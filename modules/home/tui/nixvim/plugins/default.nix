{
  imports = [
    ./lsp.nix
    ./telescope.nix
    ./treesitter.nix
    ./vimwiki.nix
  ];

  programs.nixvim.plugins = {
    gitsigns = {
      enable = true;
      settings.signs = {
        add.text = "+";
        change.text = "~";
      };
    };

    nvim-autopairs.enable = true;

    colorizer = {
      enable = true;
      # userDefaultOptions.names = false;
    };

    oil.enable = true;

    render-markdown.enable = true;

    trim = {
      enable = true;
      settings = {
        highlight = true;
        ft_blocklist = [
          "checkhealth"
          "floaterm"
          "lspinfo"
          "neo-tree"
          "TelescopePrompt"
        ];
      };
    };

    web-devicons.enable = true;
  };
}
