{
  config,
  pkgs,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.code-cursor; # AI-powered code editor built on vscode

    profiles.default = {
      enableUpdateCheck = false;

      # https://search.nixos.org/packages?type=packages&query=vscode-extensions
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        esbenp.prettier-vscode # Code formatter using prettier
        kamadorueda.alejandra # Uncompromising Nix Code Formatter
        llvm-vs-code-extensions.vscode-clangd # C/C++ completion, navigation, and insights
        ms-python.black-formatter # Formatter extension for Visual Studio Code using black
        ms-python.python # Visual Studio Code extension with rich support for the Python language
        ms-vsliveshare.vsliveshare # Real-time collaborative development for VS Code
        rust-lang.rust-analyzer # Alternative rust language server to the RLS
        myriad-dreamin.tinymist # VSCode extension for providing an integration solution for Typst
        redhat.vscode-yaml
        tomoki1207.pdf # Show PDF preview in VSCode
      ];

      userSettings = {
        # Enable colorization of matching brackets for better readability
        "editor.bracketPairColorization.enabled" = true;

        "editor.fontSize" = 16;
        "editor.fontFamily" = "'Fira Code Mono', 'monospace', monospace";

        # Automatically format code on paste, type, and save
        "editor.formatOnSave" = true;
        "editor.formatOnSaveMode" = "modifications"; # Only format modified lines on save
        "editor.formatOnPaste" = true;
        "editor.formatOnType" = true;

        # Make hover popups non-sticky so they disappear when the mouse moves away
        "editor.hover.sticky" = false;

        # Add vertical rulers at columns 79, 88, and 100 for code formatting guidelines
        "editor.rulers" = [79 88 100];

        # Associate *.txt files with the "msg" plugin for better editing of CMakeLists.txt
        "files.associations" = {
          "*.txt" = "msg";
        };

        # Automatically save files when the editor loses focus
        "files.autoSave" = "onFocusChange";

        # Exclude certain files and directories from the file explorer
        "files.exclude" = {
          "**/.git" = true; # Exclude Git directories
          "**/.svn" = true; # Exclude SVN directories
          "**/.hg" = true; # Exclude Mercurial directories
          "**/CVS" = true; # Exclude CVS directories
          "**/.DS_Store" = true; # Exclude macOS DS_Store files
          "**/*.pyc" = true; # Exclude compiled Python files
        };

        # Ensure files end with a newline, trim extra newlines, and remove trailing whitespace
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;

        "[nix]"."editor.tabSize" = 2;

        # Use yapf as the Python code formatter
        "python.formatting.provider" = "yapf";

        # Specify the style file for yapf formatting
        "python.formatting.yapfArgs" = [
          "--style=/usr/share/magformat/default_styles/style.yapf"
        ];

        # Configure pylint for Python linting with Django and numpy/ompl support
        "python.linting.pylintArgs" = [
          "--load-plugins"
          "pylint_django"
          "--extension-pkg-whitelist=numpy,ompl"
        ];

        # Configure isort for sorting Python imports with a specific style
        "python.sortImports.args" = [
          "-sp /usr/share/magformat/default_styles/isort.cfg"
          "--trailing-comma"
        ];

        # Disable telemetry data collection
        "telemetry.telemetryLevel" = "off";

        # Vim-related settings for the VSCode Vim extension
        "vim.useSystemClipboard" = true; # Use the system clipboard for Vim operations
        "vim.enableNeovim" = true; # Enable Neovim integration
        "vim.leader" = "<space>"; # Set the Vim leader key to <space>
        "vim.handleKeys" = {
          "<C-c>" = false; # Disable Vim handling of Ctrl+C
          "<C-f>" = false; # Disable Vim handling of Ctrl+F
          "<C-b>" = false; # Disable Vim handling of Ctrl+B
          "<C-k>" = false; # Disable Vim handling of Ctrl+K
          "<C-w>" = false; # Disable Vim handling of Ctrl+W
          "<C-h>" = false; # Disable Vim handling of Ctrl+H
          "<C-l>" = false; # Disable Vim handling of Ctrl+L
          "<C-a>" = false; # Disable Vim handling of Ctrl+A
          "<C-x>" = false; # Disable Vim handling of Ctrl+X
          "<C-n>" = false; # Disable Vim handling of Ctrl+N
        };
        "vim.visualstar" = true; # Enable visual star search in Vim mode

        # Use a custom title bar style instead of the default GNOME style
        "window.titleBarStyle" = "custom";

        "workbench.colorTheme" = "Cursor Dark Midnight";
      };
    };
  };

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".config/Code/";
        method = "symlink";
      }
    ];
    allowOther = true;
  };
}
