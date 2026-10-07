{
  # https://github.com/folke/snacks.nvim
  # Only the modules below are enabled; snacks leaves every other module off,
  # so the picker/explorer/lazygit/image stacks stay out in favour of fzf-lua,
  # oil, and yazi. The floating terminal and the scooter integration ride on
  # snacks.terminal, which needs no setup options.
  programs.nixvim.plugins.snacks = {
    enable = true;

    settings = {
      # opencode.nvim upgrades ask() to an input prompt with in-process LSP
      # completions (rendered by blink-cmp) and highlights when snacks.input
      # is active, and select() to a previewing picker via snacks.picker.
      # Both are advertised as the recommended UI in the plugin docs.
      input.enabled = true;
      picker.enabled = true;

      # Pretty vim.notify; parity with Helix's notify plugin.
      notifier.enabled = true;

      # Large-file guard (disables expensive features over 1.5 MB) and the
      # fast path that renders a file before plugins load, which keeps the
      # nvedit/git/jj edit path snappy.
      bigfile.enabled = true;
      quickfile.enabled = true;

      # Highlights LSP references under the cursor.
      words.enabled = true;
    };
  };
}
