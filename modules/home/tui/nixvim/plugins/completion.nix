{
  programs.nixvim.plugins.blink-cmp = {
    enable = true;

    settings = {
      # Tab accepts the selected item, Shift-Tab cycles; no snippet engine
      # needed (LSP snippets expand through Neovim's native vim.snippet).
      keymap.preset = "super-tab";

      completion = {
        documentation.auto_show = true;
        ghost_text.enabled = true;
      };
    };
  };
}
