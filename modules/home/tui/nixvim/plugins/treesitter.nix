{pkgs, ...}: {
  programs.nixvim = {
    plugins = {};

    extraPlugins =
      [
        pkgs.vimPlugins.nvim-treesitter
      ]
      ++ (
        let
          grammarFile = import ../../../../../lib/treesitter-grammars.nix;
        in
          map (name: pkgs.vimPlugins.nvim-treesitter-parsers.${name}) grammarFile
      );

    extraConfigLua = ''
      require'nvim-treesitter.configs'.setup {
        auto_install = false,
        ensure_installed = {},
        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },
        parser_install_dir = nil,
      }
    '';
  };
}
