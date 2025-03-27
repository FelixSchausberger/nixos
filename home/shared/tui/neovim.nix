{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    coc.enable = true;
    # defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    plugins = with pkgs.vimPlugins; [
      yankring
      vim-nix
      vimwiki
    ];

    extraLuaConfig =
      # ''
      #   -- Plugins
      #   -- Bootstrapping
      #   local ensure_packer = function()
      #     local fn = vim.fn
      #     local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
      #     if fn.empty(fn.glob(install_path)) > 0 then
      #   fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
      #       vim.cmd [[packadd packer.nvim]]
      #       return true
      #     end
      #     return false
      #   end
      #   local packer_bootstrap = ensure_packer()
      #   return require('packer').startup(function(use)
      #     -- use { 'ms-jpq/coq_nvim', branch = 'coq' }
      #     -- use { 'ms-jpq/coq.artifacts', branch = 'artifacts' }
      #     -- use { 'ms-jpq/coq.thirdparty', branch = '3p'}
      #     use { 'junegunn/fzf', run = 'fzf#install' }
      #     use { 'wbthomason/packer.nvim' }
      #     use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
      #     -- Automatically set up your configuration after cloning packer.nvim
      #     -- Put this at the end after all plugins
      #     if packer_bootstrap then
      #       require('packer').sync()
      #     end
      #   end)
      # '' + ''
      ''
        -- Settings

        HOME = os.getenv("HOME")

        local g = vim.g
        local o = vim.o

        g.mapleader = ','
        g.maplocalleader = '\\'

        -- Basic settings
        o.encoding = "utf-8"
        o.backspace = "indent,eol,start" -- backspace works on every char in insert mode
        o.completeopt = 'menuone,noselect'
        o.history = 1000
        o.dictionary = '/usr/share/dict/words'
        o.startofline = true

        -- Mapping waiting time
        o.timeout = false
        o.ttimeout = true
        o.ttimeoutlen = 100

        -- Display
        o.showmatch  = true -- show matching brackets
        o.scrolloff = 3 -- always show 3 rows from edge of the screen
        o.synmaxcol = 300 -- stop syntax highlight after x lines for performance
        o.laststatus = 2 -- always show status line

        o.list = false -- do not display white characters
        o.foldenable = false
        o.foldlevel = 4 -- limit folding to 4 levels
        o.foldmethod = 'syntax' -- use language syntax to generate folds
        o.wrap = false --do not wrap lines even if very long
        o.eol = false -- show if there's no eol char
        o.showbreak= '↪' -- character to show when line is broken

        -- Sidebar
        o.number = true -- line number on the left
        o.numberwidth = 3 -- always reserve 3 spaces for line number
        o.signcolumn = 'yes' -- keep 1 column for coc.vim  check
        o.modelines = 0
        o.showcmd = true -- display command in bottom bar

        -- Search
        o.incsearch = true -- starts searching as soon as typing, without enter needed
        o.ignorecase = true -- ignore letter case when searching
        o.smartcase = true -- case insentive unless capitals used in search

        o.matchtime = 2 -- delay before showing matching paren
        o.mps = o.mps .. ",<:>"

        -- White characters
        o.autoindent = true
        o.smartindent = true
        o.tabstop = 2 -- 1 tab = 2 spaces
        o.shiftwidth = 2 -- indentation rule
        o.formatoptions = 'qnj1' -- q  - comment formatting; n - numbered lists; j - remove comment when joining lines; 1 - don't break after one-letter word
        o.expandtab = true -- expand tab to spaces

        -- Save backup and undo files
        o.backup = true -- use backup files
        o.writebackup = true
        o.undofile = true -- use undo files

        if !isdirectory($HOME."/.vim")
            call mkdir($HOME."/.vim", "", 0770)
        endif
        if !isdirectory($HOME."/.vim/tmp")
            call mkdir($HOME."/.vim/tmp", "", 0700)
        endif
        if !isdirectory($HOME."/.vim/tmp/undo")
            call mkdir($HOME."/.vim/tmp/undo", "", 0770)
        endif
        if !isdirectory($HOME."/.vim/tmp/backup")
            call mkdir($HOME."/.vim/tmp/backup", "", 0700)
        endif

        o.undodir = HOME .. '/.vim/tmp/undo//'     -- undo files
        o.backupdir = HOME .. '/.vim/tmp/backup//' -- backups

        vim.cmd([[
          au FileType python                  set ts=4 sw=4
          au BufRead,BufNewFile *.md          set ft=mkd tw=80 syntax=markdown
          au BufRead,BufNewFile *.ppmd        set ft=mkd tw=80 syntax=markdown
          au BufRead,BufNewFile *.markdown    set ft=mkd tw=80 syntax=markdown
          au BufRead,BufNewFile *.slimbars    set syntax=slim
        ]])

        -- Commands mode
        o.wildmenu = true -- on TAB, complete options for system command
        o.wildignore = 'deps,.svn,CVS,.git,.hg,*.o,*.a,*.class,*.mo,*.la,*.so,*.obj,*.swp,*.jpg,*.png,*.xpm,*.gif,.DS_Store,*.aux,*.out,*.toc'

        -- Only show cursorline in the current window and in normal mode.
        vim.cmd([[
          augroup cline
              au!
              au WinLeave * set nocursorline
              au WinEnter * set cursorline
              au InsertEnter * set nocursorline
              au InsertLeave * set cursorline
          augroup END
        ]])

        o.background = 'dark'

        g.python3_host_prog = "/usr/bin/python3"
        g.python_host_prog = "/usr/bin/python2"

        -- Use ´Fuck´ to save when file is read only
        vim.cmd 'command! Fuck w !sudo tee %'

        vim.g.vimwiki_list = {{path = '/mnt/gdrive/Obsidian', syntax = 'markdown', ext = '.md'}}

      ''
      + ''
        -- Mappings

        vim.cmd('noremap <C-b> :noh<cr>:call clearmatches()<cr>') -- clear matches Ctrl+b

        function map(mode, shortcut, command)
          vim.api.nvim_set_keymap(mode, shortcut, command, { noremap = true, silent = true })
        end

        function nmap(shortcut, command)
          map('n', shortcut, command)
        end

        function imap(shortcut, command)
          map('i', shortcut, command)
        end

        function vmap(shortcut, command)
          map('v', shortcut, command)
        end

        function cmap(shortcut, command)
          map('c', shortcut, command)
        end

        function tmap(shortcut, command)
          map('t', shortcut, command)
        end

        -- Define a function to find incomplete tasks within the current Vimwiki file
        function vimwiki_find_incomplete_tasks()
          vim.cmd([[lvimgrep /- \[ \]/ %:p]])
          vim.cmd([[lopen]])
        end

        -- Define a function to find all incomplete tasks across all Vimwiki files
        function vimwiki_find_all_incomplete_tasks()
          vim.cmd([[VimwikiSearch /- \[ \]/]])
          vim.cmd([[lopen]])
        end

        -- Map a keybinding to find all incomplete tasks
        nmap('wa', ':lua vimwiki_find_all_incomplete_tasks()<CR>')

        -- Map a keybinding to find incomplete tasks in the current file
        nmap('wx', ':lua vimwiki_find_incomplete_tasks()<CR>')

        -- map('``', ':nohlsearch<CR>:call minimap#vim#ClearColorSearch()<CR>')

        -- Search
        -- Keep search matches in the middle of the window
        nmap('n', 'nzzzv')
        nmap('N', 'Nzzzv')

        -- Same when jumping around
        nmap('g;', 'g;zz')

        -- Clipboard
        vmap('<C-c>', '"+yi')
        vmap('<C-x>', '"+c')
        vmap('<C-v>', 'c<ESC>"+p')
        imap('<C-v', '<ESC>"+pa')
      '';
  };
}
