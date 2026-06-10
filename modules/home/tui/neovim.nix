{pkgs, ...}: {
  home.packages = with pkgs; [
    (neovim.override {
      configure = {
        customRC = ''
          " Basic configuration
          set number
          set relativenumber
          set expandtab
          set tabstop=2
          set shiftwidth=2
          set smartindent
          set ignorecase
          set smartcase
          set incsearch
          set hlsearch

          " Key mappings
          let mapleader = " "
          nnoremap <leader>w :w<CR>
          nnoremap <leader>q :q<CR>

          " Tree-sitter: parsers bundled by Nix, highlighting via built-in treesitter
          lua << EOF
          require'nvim-treesitter'.setup {}
          EOF

          " Markdown rendering setup (requires render-markdown.nvim)
          lua << EOF
          local ok, render = pcall(require, "render-markdown")
          if ok then
            render.setup({})
          end
          EOF

          augroup MarkdownRender
            autocmd!
            autocmd FileType markdown if exists(":RenderMarkdown") | silent RenderMarkdown | endif
          augroup END

          " Window title for Niri mode-based border colors
          set title
          lua << EOF
          local mode_names = {
            n = "NORMAL", i = "INSERT", v = "VISUAL",
            V = "V-LINE", ["\22"] = "V-BLOCK",
            c = "COMMAND", R = "REPLACE", r = "PROMPT",
            ["!"] = "SHELL", t = "TERMINAL",
          }
          local function update_niri_title()
            local mode = vim.fn.mode()
            local mode_str = mode_names[mode] or "NORMAL"
            vim.opt.titlestring = "nvim [" .. mode_str .. "]"
          end
          vim.api.nvim_create_autocmd({ "ModeChanged", "VimEnter" }, {
            callback = update_niri_title,
          })
          EOF

          " Launch Yazi inside Neovim from the current file directory
          function! OpenYaziHere()
            let l:startDir = expand('%:p:h')
            if empty(l:startDir)
              let l:startDir = getcwd()
            endif
            tabnew
            execute 'terminal yazi ' . fnameescape(l:startDir)
            startinsert
          endfunction
          nnoremap <leader>yy :call OpenYaziHere()<CR>
        '';

        packages.myVimPackage = {
          start =
            [
              pkgs.vimPlugins.vim-commentary
              pkgs.vimPlugins.vim-surround
              pkgs.vimPlugins.render-markdown-nvim
              pkgs.vimPlugins.nvim-treesitter
            ]
            ++ (
              let
                grammarFile = import ../../../lib/treesitter-grammars.nix;
              in
                map (name: pkgs.vimPlugins.nvim-treesitter-parsers.${name}) grammarFile
            );
        };
      };
    })
  ];

  home.shellAliases = {
    v = "nvim";
    vim = "nvim";
    vi = "nvim";
  };
}
