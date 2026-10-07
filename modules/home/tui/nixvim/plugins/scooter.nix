{
  programs.nixvim = {
    keymaps = [
      {
        mode = "n";
        key = "<leader>ss";
        action = "<cmd>lua scooter_open()<cr>";
        options = {
          silent = true;
          desc = "scooter (project replace)";
        };
      }
      {
        mode = "x";
        key = "<leader>ss";
        action = "<cmd>lua scooter_open_selection()<cr>";
        options = {
          silent = true;
          desc = "scooter from selection";
        };
      }
    ];
  };

  # scooter's `e` on a result shells out to this command. `nvim --remote-send`
  # is non-blocking, unlike nvedit's `nvr --remote-wait`, so scooter keeps
  # running while the file opens; EditLineFromScooter hides the float and jumps
  # to the matching line. base16-mocha.dark is the closest built-in syntect
  # theme to catppuccin_mocha; no theme asset to vendor.
  home.file.".config/scooter/config.toml".text = ''
    [editor_open]
    command = "nvim --server $NVIM --remote-send '<cmd>lua EditLineFromScooter(\"%file\", %line)<CR>'"
    exit = true

    [preview]
    syntax_highlighting_theme = "base16-mocha.dark"
    wrap_text = true
  '';
}
