_: {
  programs.nixvim = {
    globals = {
      # Space as leader, matching Helix's space-prefixed commands. Must be set
      # before any plugin keymaps are registered.
      mapleader = " ";
      maplocalleader = " ";

      # Disable unused providers
      loaded_ruby_provider = 0; # Ruby
      loaded_perl_provider = 0; # Perl
    };

    clipboard = {
      # Use system clipboard
      register = "unnamedplus";

      providers.wl-copy.enable = true;
    };

    opts = {
      updatetime = 100; # Faster completion
      timeoutlen = 300; # Snappier which-key/leader hints (default 1000)

      # Line numbers
      number = true; # Display the absolute line number of the current line
      relativenumber = true; # Relative line numbers
      cursorline = true; # Highlight the screen line of the cursor (Helix parity)
      signcolumn = "yes"; # Whether to show the signcolumn

      # Indentation: Helix defaults to an indent width of 4
      expandtab = true; # Expand <Tab> to spaces in Insert mode
      tabstop = 4; # Number of spaces a <Tab> in the text stands for
      shiftwidth = 4; # Number of spaces used for each step of (auto)indent
      smartindent = true; # Do clever autoindenting

      # Search
      ignorecase = true; # When the search query is lower-case, match both cases
      smartcase = true; # Override ignorecase when the pattern has upper-case chars
      incsearch = true; # Show matches for the partly typed search command
      hlsearch = true; # Highlight the last used search pattern

      # No soft wrap for code (Helix's default); markdown soft-wraps via
      # FileType autocmd, see autocommands.nix.
      wrap = false;

      # Windows
      splitbelow = true; # A new window is put below the current one
      splitright = true; # A new window is put right of the current one
      scrolloff = 8; # Number of screen lines to show around the cursor

      # Files and history
      hidden = true; # Keep closed buffer open in the background
      undofile = true; # Automatically save and restore undo history
      swapfile = false; # Disable the swap file
      confirm = true; # Offer to save instead of failing on :q/:e with changes
      modeline = true; # Recognize 'vim:ft=sh' modelines
      modelines = 100; # Number of lines checked for modelines

      # UI
      termguicolors = true; # Enables 24-bit RGB color in the TUI
      laststatus = 3; # Use a single global status line
      colorcolumn = "100"; # Column to highlight
      title = true; # Set the window title; Niri's border rules match on it
      winborder = "rounded"; # Border for floating windows (nvim 0.11+)
      mouse = "a"; # Enable mouse control
      mousemodel = "extend"; # Right-click extends the selection instead of a popup
      inccommand = "split"; # Preview substitutions in a split

      # Treesitter folds start fully open (foldmethod/foldexpr are set by the
      # treesitter module); without these a file would render fully folded.
      foldlevel = 99;
      foldlevelstart = 99;
    };
  };
}
