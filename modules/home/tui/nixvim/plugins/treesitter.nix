{
  config,
  pkgs,
  ...
}: let
  # Curated parser list (see lib/treesitter-grammars.nix); allGrammars would
  # rebuild every grammar for languages this config never opens.
  grammarNames = import ../../../../../lib/treesitter-grammars.nix;
  grammars = config.programs.nixvim.plugins.treesitter.package.builtGrammars;
in {
  programs.nixvim = {
    # tree-sitter CLI for nvim-treesitter's :checkhealth and parser
    # maintenance; it is not part of the shared editor package set.
    extraPackages = [pkgs.tree-sitter];

    plugins.treesitter = {
      enable = true;
      grammarPackages = map (name: grammars.${name}) grammarNames;

      highlight.enable = true; # Tree-sitter based syntax highlighting
      indent.enable = true; # Tree-sitter based indentation
      folding.enable = true; # foldexpr from vim.treesitter (foldlevel lives in options.nix)
    };
  };
}
