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
        '';

        packages.myVimPackage = with pkgs.vimPlugins; {
          start = [
            # Core plugins
            vim-commentary
            vim-surround

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
