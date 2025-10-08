{pkgs, ...}: {
  # Disable nixvim's treesitter plugins to prevent HTTP 401 errors
  # Use nix-managed grammars instead
  programs.nixvim = {
    plugins = {};

    # Add tree-sitter support via extraPlugins with nix-managed grammars
    extraPlugins = with pkgs.vimPlugins; [
      # Use withPlugins to specify only the grammars we need
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

    # Configure treesitter via lua to avoid nixvim's grammar fetching
    extraConfigLua = ''
      require'nvim-treesitter.configs'.setup {
        -- Disable auto installation completely
        auto_install = false,
        ensure_installed = {}, -- Empty to prevent any automatic installation

        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },

        -- Only use parsers installed via nix
        parser_install_dir = nil,
      }
    '';
  };
}
