{
  config,
  lib,
  pkgs,
  ...
}: {
  home = {
    packages = with pkgs; [
      icu # Required for .NET globalization support (MCP servers)
      # Create a 'code' symlink to vscodium/code executable
      (pkgs.writeShellScriptBin "code" ''
        exec ${config.programs.vscode.package}/bin/${
          if config.programs.vscode.package == pkgs.vscodium
          then "codium"
          else "code"
        } "$@"
      '')
    ];

    sessionVariables = {
      GDK_BACKEND = "wayland";
      # Network stability enhancements
      DISABLE_REQUEST_THROTTLING = "1";
      ELECTRON_FORCE_WINDOW_MENU_BAR = "1";
      # Increase connection pools and timeouts
      CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
      CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium; # pkgs.cursor

    profiles = {
      default = {
        enableUpdateCheck = false;

        # https://search.nixos.org/packages?type=packages&query=vscode-extensions
        extensions = with pkgs.vscode-extensions; [
          kamadorueda.alejandra # Uncompromising Nix Code Formatter
          ms-python.black-formatter # Formatter extension for Visual Studio Code using black
          ms-vscode.cpptools # C++ support
          mkhl.direnv # Direnv support for Visual Studio Code
          donjayamanne.githistory # View git log, file history, compare branches or commits
          gitlab.gitlab-workflow # GitLab extension for Visual Studio Code
          bbenoist.nix # Nix support
          christian-kohler.path-intellisense # Path autocomplete
          tomoki1207.pdf # Show PDF preview in VSCode
          esbenp.prettier-vscode # Code formatter using prettier
          ms-python.python # Visual Studio Code extension with rich support for the Python language
          rust-lang.rust-analyzer # Alternative rust language server to the RLS
          myriad-dreamin.tinymist # VSCode extension for providing an integration solution for Typst
          llvm-vs-code-extensions.vscode-clangd # C/C++ completion, navigation, and insights
          redhat.vscode-yaml # YAML Language Support by Red Hat, with built-in Kubernetes syntax support
          ms-vsliveshare.vsliveshare # Real-time collaborative development for VS Code
        ];

        userSettings = {
          # Enable colorization of matching brackets for better readability
          "editor" = {
            "bracketPairColorization.enabled" = true;

            "codeActionsOnSave" = {
              "source.organizeImports" = "explicit";
              "source.fixAll" = "explicit";
            };

            "detectIndentation" = true;

            "fontFamily" = lib.mkDefault "'Fira Code Mono', 'monospace', monospace";
            "fontLigatures" = true;
            "fontSize" = 16;

            # Automatically format code on paste, type, and save
            "formatOnPaste" = true;
            "formatOnSave" = true;
            "formatOnSaveMode" = "modifications"; # Only format modified lines on save
            "formatOnType" = true;

            "guides.bracketPairs" = "active";

            "insertSpaces" = true;

            # Make hover popups non-sticky so they disappear when the mouse moves away
            "hover.sticky" = false;

            # Wayland optimization settings
            "renderWhitespace" = "all";

            # Add vertical rulers at columns 79, 88, and 100 for code formatting guidelines
            "rulers" = [79 88 100];
            "smoothScrolling" = true;

            "tabSize" = 2;
            "trimAutoWhitespace" = true;
          };

          # Associate *.txt files with the "msg" plugin for better editing of CMakeLists.txt
          "files" = {
            "associations" = {
              "*.txt" = "msg";
            };

            # Automatically save files when the editor loses focus
            "autoSave" = "onFocusChange";

            # Exclude certain files and directories from the file explorer
            "exclude" = {
              "**/*.pyc" = true; # Exclude compiled Python files
              "**/.DS_Store" = true; # Exclude macOS DS_Store files
              "**/.git" = true; # Exclude Git directories
              "**/.hg" = true; # Exclude Mercurial directories
              "**/.svn" = true; # Exclude SVN directories
              "**/CVS" = true; # Exclude CVS directories
              "**/.direnv" = true;
              "**/result" = true;
            };

            # Ensure files end with a newline, trim extra newlines, and remove trailing whitespace
            "insertFinalNewline" = true;
            "trimFinalNewlines" = true;
            "trimTrailingWhitespace" = true;

            # Performance optimizations
            "watcherExclude" = {
              "**/node_modules/**" = true;
              "**/target/**" = true;
              "**/result/**" = true;
              "**/.direnv/**" = true;
              "**/.git/**" = true;
              "**/dist/**" = true;
              "**/build/**" = true;
            };
          };

          # Git settings
          "git" = {
            "enableSmartCommit" = true;
            "confirmSync" = false;
            "autofetch" = true;
            "fetchOnPull" = true;
            "pruneOnFetch" = true;
            "openRepositoryInParentFolders" = "always";
            "showPushSuccessNotification" = true;
            "enableCommitSigning" = false;
            "path" = pkgs.git;
          };
          "diffEditor.ignoreTrimWhitespace" = false;

          # Nix-specific settings
          "[nix]" = {
            "diagnostics" = {
              "ignored" = [];
              "excluded" = [
                ".direnv/**"
                "result/**"
                ".git/**"
                "node_modules/**"
              ];
            };
            "editor" = {
              "defaultFormatter" = "kamadorueda.alejandra";
            };
            "enableLanguageServer" = true;
            "env" = {
              "NIX_PATH" = "nixpkgs=channel:nixos-unstable";
            };
            "formatterWidth" = 100;
            "serverPath" = "nixd";
            "serverSettings" = {
              "nixd" = {
                "formatting" = {
                  "command" = ["alejandra"];
                  "timeout_ms" = 5000;
                };
                # Options configuration removed to fix builtins.toFile warnings
                # These provide option completion in nixd but are optional
                # The configuration referenced non-existent host "p620" and caused evaluation warnings
                # Users can add host-specific options configuration if needed
                "diagnostics" = {
                  "enable" = true;
                  "ignored" = [];
                  "excluded" = [
                    "\\.direnv"
                    "result"
                    "\\.git"
                    "node_modules"
                  ];
                };
                "eval" = {
                  "depth" = 2;
                  "workers" = 3;
                  "trace" = {
                    "server" = "off";
                    "evaluation" = "off";
                  };
                };
                "completion" = {
                  "enable" = true;
                  "priority" = 10;
                  "insertSingleCandidateImmediately" = true;
                };
                "path" = {
                  "include" = ["**/*.nix"];
                  "exclude" = [
                    ".direnv/**"
                    "result/**"
                    ".git/**"
                    "node_modules/**"
                  ];
                };
                "lsp" = {
                  "progressBar" = true;
                  "snippets" = true;
                  "logLevel" = "info";
                  "maxIssues" = 100;
                  "failureHandling" = {
                    "retry" = {
                      "max" = 3;
                      "delayMs" = 1000;
                    };
                    "fallbackToOffline" = true;
                  };
                };
              };
            };

            # Context7 MCP configuration
            "mcp" = {
              "servers" = {
                "Context7" = {
                  "type" = "stdio";
                  "command" = "npx";
                  "args" = [
                    "-y"
                    "@upstash/context7-mcp@latest"
                  ];
                };
                "nixos" = {
                  "type" = "stdio";
                  "command" = "nix";
                  "args" = [
                    "shell"
                    "nixpkgs#uv"
                    "--command"
                    "uvx"
                    "mcp-nixos@0.3.1"
                  ];
                };
                "terraform-registry" = {
                  "command" = "npx";
                  "args" = [
                    "-y"
                    "terraform-mcp-server"
                  ];
                };
                "gcp" = {
                  "command" = "sh";
                  "args" = [
                    "-c"
                    "npx -y gcp-mcp"
                  ];
                };
                "github" = {
                  "type" = "stdio";
                  "command" = "npx";
                  "args" = [
                    "-y"
                    "@modelcontextprotocol/server-github"
                  ];
                  "env" = {
                    "GITHUB_PERSONAL_ACCESS_TOKEN" = "${config.sops.secrets."github/token".path}";
                  };
                };
              };
            };
          };

          # https://github.com/utensils/mcp-nixos
          "nixos"."command" = "nix run github:utensils/mcp-nixos --";

          "python" = {
            "editor" = {
              "defaultFormatter" = "ms-python.black-formatter";
              "formatOnSave" = true;
              "codeActionsOnSave" = {
                "source.organizeImports" = "explicit";
              };
            };

            # "formatting = {
            #   # Use yapf as the Python code formatter
            #   "provider" = "yapf";

            #   # Specify the style file for yapf formatting
            #   "yapfArgs" = [
            #     "--style=/usr/share/magformat/default_styles/style.yapf"
            #   ];
            # };

            # Configure pylint for Python linting with Django and numpy/ompl support
            "linting.pylintArgs" = [
              "--load-plugins"
              "pylint_django"
              "--extension-pkg-whitelist=numpy,ompl"
            ];

            # Configure isort for sorting Python imports with a specific style
            "sortImports.args" = [
              "-sp /usr/share/magformat/default_styles/isort.cfg"
              "--trailing-comma"
            ];
          };

          # Rust settings
          "[rust]" = {
            "editor.defaultFormatter" = "rust-lang.rust-analyzer";
            "editor.formatOnSave" = true;
          };

          # Performance optimizations
          "search.exclude" = {
            "**/node_modules" = true;
            "**/target" = true;
            "**/result" = true;
            "**/.direnv" = true;
            "**/dist" = true;
            "**/build" = true;
          };

          # Disable settings sync to prevent conflicts with declarative configuration
          "settingsSync" = {
            "enabled" = false;
            "keybindingsPerPlatform" = false;
          };

          # Disable telemetry data collection
          "telemetry.telemetryLevel" = "off";

          "terminal.integrated" = {
            "gpuAcceleration" = "on";
            "scrollback" = 10000;
          };

          "[typst]"."editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";

          "update.mode" = "none"; # Managed by Nix

          # Vim-related settings for the VSCode Vim extension
          "vim" = {
            "enableNeovim" = true; # Enable Neovim integration
            "handleKeys" = {
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
            "leader" = "<space>"; # Set the Vim leader key to <space>
            "useSystemClipboard" = true; # Use the system clipboard for Vim operations
            "visualstar" = true; # Enable visual star search in Vim mode
          };

          # Wayland optimization settings
          "window" = {
            "titleBarStyle" = "custom"; # Use a custom title bar style instead of the default GNOME style
            "customTitleBarVisibility" = "auto";
            "nativeTabs" = false; # Native tabs don't work well with Wayland
            "nativeFullScreen" = true;
            "zoomLevel" = 1.5; # 150% zoom
          };

          "workbench" = {
            "colorTheme" = "Cursor Dark Midnight";
            "list.smoothScrolling" = true;
            "startupEditor" = "welcomePageInEmptyWorkbench";
            "sideBar.location" = "left";
            "view.alwaysShowHeaderActions" = false;
            "activityBar.visible" = true;
            "panel.defaultLocation" = "bottom";
            # Hide outline and timeline views from sidebar
            "outline.showFiles" = false;
            "outline.showModules" = false;
            "outline.showNamespaces" = false;
            "outline.showPackages" = false;
            "outline.showClasses" = false;
            "outline.showMethods" = false;
            "outline.showProperties" = false;
            "outline.showFields" = false;
            "outline.showConstructors" = false;
            "outline.showEnums" = false;
            "outline.showInterfaces" = false;
            "outline.showFunctions" = false;
            "outline.showVariables" = false;
            "outline.showConstants" = false;
            "outline.showStrings" = false;
            "outline.showNumbers" = false;
            "outline.showBooleans" = false;
            "outline.showArrays" = false;
            "outline.showObjects" = false;
            "outline.showKeys" = false;
            "outline.showNull" = false;
            "outline.showEnumMembers" = false;
            "outline.showStructs" = false;
            "outline.showEvents" = false;
            "outline.showOperators" = false;
            "outline.showTypeParameters" = false;
            "timeline.showView" = false;
          };
        };
      };
    };
  };

  # Set up XDG file associations for VSCode
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "text/plain" = ["code.desktop"];
      "text/markdown" = ["code.desktop"];
      "application/json" = ["code.desktop"];
      "application/x-yaml" = ["code.desktop"];
      "text/x-python" = ["code.desktop"];
      "text/x-csrc" = ["code.desktop"];
      "text/x-c++src" = ["code.desktop"];
      "text/x-chdr" = ["code.desktop"];
      "text/x-c++hdr" = ["code.desktop"];
      "text/x-shellscript" = ["code.desktop"];
      "text/html" = ["code.desktop"];
      "text/css" = ["code.desktop"];
      "text/javascript" = ["code.desktop"];
    };
  };

  sops.secrets = {
    "github/token" = {};
  };

  # Custom VSCode desktop entry with Wayland optimizations
  xdg.desktopEntries.code = {
    name = "Visual Studio Code";
    exec = "code %F";
    categories = ["Development" "IDE"];
    comment = "Code Editing. Optimized for Wayland.";
    # icon = "code";
    mimeType = [
      "text/plain"
      "text/markdown"
      "application/json"
      "application/x-yaml"
      "text/x-python"
      "text/x-csrc"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-c++hdr"
      "text/x-shellscript"
      "text/html"
      "text/css"
      "text/javascript"
    ];
    type = "Application";
  };
}
