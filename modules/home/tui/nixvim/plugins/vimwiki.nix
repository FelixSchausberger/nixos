{
  programs.nixvim.plugins.vimwiki = {
    enable = true;
    settings = {
      autowriteall = 0;
      global_ext = 0;
      hl_cb_checked = 1;
      hl_headers = 1;
      key_mappings = {
        all_maps = 1;
        global = 1;
        headers = 1;
      };
      list = [
        {
          ext = ".md";
          path = "/mnt/gdrive/Obsidian";
          syntax = "markdown";
        }
      ];
      listsym_rejected = "✗";
      listsyms = "○◐●✓";
      use_calendar = 1;
    };
  };
}
