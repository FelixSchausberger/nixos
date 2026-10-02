{
  programs.nixvim.plugins.blink-cmp = {
    enable = true;

    settings = {
      # The menu only ever shows hints: suggestions pop up while typing and
      # ghost text previews them, but nothing is inserted without an explicit
      # <C-y>. Tab and Enter keep their indent/newline behavior, so typing is
      # never hijacked by an accept. Navigate with <C-n>/<C-p> or the arrows,
      # dismiss with <C-e>, toggle manually with <C-space>. Snippets run
      # through Neovim's native vim.snippet, no engine needed.
      keymap.preset = "default";

      completion = {
        documentation.auto_show = true;
        ghost_text.enabled = true;
      };
    };
  };
}
