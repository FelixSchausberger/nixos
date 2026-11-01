{
  programs.nixvim.autoCmd = [
    # Vertically center document when entering insert mode
    {
      event = "InsertEnter";
      command = "norm zz";
    }

    # Open help in a vertical split
    {
      event = "FileType";
      pattern = "help";
      command = "wincmd L";
    }

    # Soft-wrap prose like Helix's markdown soft-wrap; code stays unwrapped.
    # linebreak breaks at word boundaries and breakindent hangs continuation
    # lines; on nvim 0.13+ the wrap layout is conceal-aware, so it stays
    # correct around render-markdown's concealed syntax.
    {
      event = "FileType";
      pattern = "markdown";
      command = "setlocal wrap linebreak breakindent";
    }

    # Enable spellcheck for some filetypes
    {
      event = "FileType";
      pattern = [
        "tex"
        "latex"
        "markdown"
      ];
      command = "setlocal spell spelllang=en,fr";
    }
  ];
}
