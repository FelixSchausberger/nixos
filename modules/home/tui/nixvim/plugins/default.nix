{pkgs, ...}: {
  imports = [
    ./completion.nix
    ./conform.nix
    ./lsp.nix
    ./opencode.nix
    ./rust.nix
    ./treesitter.nix
  ];

  programs.nixvim = {
    # mini.icons backs which-key's icon rendering (its first-choice provider,
    # probed with pcall so it needs an explicit setup()); nixvim ships no mini
    # module, hence the bare plugin.
    extraPlugins = [pkgs.vimPlugins.mini-nvim];
    extraConfigLua = ''
      require("mini.icons").setup()
    '';

    # Match Helix's catppuccin_mocha theme
    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "mocha";
    };

    plugins = {
      # https://github.com/lewis6991/gitsigns.nvim
      gitsigns.enable = true; # Git signs in the sign column

      # https://github.com/stevearc/oil.nvim
      oil.enable = true; # File explorer

      # https://github.com/ibhagwan/fzf-lua
      fzf-lua.enable = true; # Pickers (files, grep, buffers, ...)

      # https://github.com/mikavilpas/yazi.nvim
      yazi.enable = true; # Yazi inside Neovim

      # https://github.com/MeanderingProgrammer/render-markdown.nvim
      render-markdown = {
        enable = true; # Improve viewing Markdown

        # Rendering $...$ spans needs the latex tree-sitter parser plus the
        # utftex and latex2text CLIs, none of which this config ships, so the
        # plugin's :checkhealth advises disabling the feature outright.
        settings.latex.enabled = false;
      };

      # https://github.com/tpope/vim-commentary
      commentary.enable = true; # gc to comment (same as the previous setup)

      # https://github.com/tpope/vim-surround
      vim-surround.enable = true; # cs/yss/ds surround operations

      # https://github.com/nvim-tree/nvim-web-devicons
      web-devicons.enable = true; # Provides Nerd Font icons (glyphs)

      # https://github.com/stevearc/overseer.nvim
      # Task runner for the cargo keymaps. Its builtin cargo template is
      # discovered from the runtimepath and offers check/build/run/test for
      # every directory containing a Cargo.toml.
      overseer.enable = true;
    };
  };
}
