{
  imports = [
    # ./claude-code.nix
    ./lsp.nix
    ./telescope.nix
    # ./treesitter.nix
    ./vimwiki.nix
    ./obsidian.nix
  ];

  programs.nixvim.plugins = {
    # https://github.com/lewis6991/gitsigns.nvim
    gitsigns = {
      # Git integration for buffers
      enable = true;
      settings.signs = {
        add.text = "+";
        change.text = "~";
      };
    };

    # https://github.com/ggandor/leap.nvim
    leap.enable = true; # Neovim's answer to the mouse

    # https://github.com/windwp/nvim-autopairs
    nvim-autopairs.enable = true;

    # https://github.com/norcalli/nvim-colorizer.lua
    colorizer = {
      enable = true;
      # userDefaultOptions.names = false;
    };

    # https://github.com/stevearc/oil.nvim
    oil.enable = true; # Neovim file explorer

    # https://github.com/MeanderingProgrammer/render-markdown.nvim
    render-markdown.enable = true; # Improve viewing Markdown

    # https://github.com/cappyzawa/trim.nvim
    trim = {
      # This plugin trims trailing whitespace and lines.
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

    # https://github.com/nvim-tree/nvim-web-devicons
    web-devicons.enable = true; # Provides Nerd Font icons (glyphs)
  };
}
