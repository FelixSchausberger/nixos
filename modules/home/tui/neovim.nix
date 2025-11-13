{pkgs, ...}: {
  home.packages = with pkgs; [
    # Neovim with tree-sitter grammars (avoiding nixvim's tree-sitter-ada issue)
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

          " Tree-sitter setup
          lua << EOF
          require'nvim-treesitter.configs'.setup {
            highlight = { enable = true },
            indent = { enable = true },
            -- Disable auto installation to avoid HTTP 401 errors
            auto_install = false,
            ensure_installed = {},
          }
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

        packages.myVimPackage = with pkgs.vimPlugins; {
          start = [
            # Core plugins
            vim-commentary
            vim-surround
            render-markdown-nvim

            # Tree-sitter with specific grammars to avoid ada issue
            (nvim-treesitter.withPlugins (p:
              with p; [
                bash
                c
                cpp
                css
                dockerfile
                fish
                go
                html
                javascript
                json
                lua
                markdown
                nix
                python
                rust
                toml
                typescript
                vim
                yaml
              ]))
          ];
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
