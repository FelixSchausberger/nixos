{
  config,
  pkgs,
  ...
}: {
  home = {
    packages = with pkgs; [
      icu # Required for .NET globalization support (MCP servers)

      # Performance and compatibility tools for NixOS
      vulkan-tools # For Vulkan debugging and validation
      vulkan-loader # Vulkan compatibility
    ];

    sessionVariables = {
      GDK_BACKEND = "wayland";
      # Network stability enhancements
      DISABLE_REQUEST_THROTTLING = "1";
      # Increase connection pools and timeouts
      CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
      CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";

      # NixOS-specific optimizations for Zed
      # Vulkan support (required for Zed) - Auto-detected drivers
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json:/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      # GPU library paths
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      # Mesa GPU acceleration
      MESA_GL_VERSION_OVERRIDE = "4.6";
    };
  };

  programs.zed-editor = {
    enable = true;

    # Extensions using Home Manager's built-in support
    extensions = [
      "nix"
      "catppuccin-macchiatoblur" # Catppuccin theme with blur effects
      "catppuccin-macchiatoicons" # Catppuccin-styled icons
      "toml"
      "dockerfile"
      "git-firefly"
      "typst"
      "prettier"
      "eslint"
      "mcp-server-gitlab"
    ];

    # Additional packages available to Zed's environment
    extraPackages = with pkgs; [
      # LSP servers
      nixd
      pyright
      clang-tools
      marksman

      # Formatters
      alejandra
      black
      nodePackages.prettier

      # Additional tools
      claude-code
    ];

    userSettings = {
      # Theme and appearance
      theme = {
        mode = "dark";
        light = "Catppuccin Latte";
        dark = "Catppuccin Mocha (Blur)"; # Using the blur theme from catppuccin-macchiatoblur extension
      };

      # Window transparency (requires compositor support)
      window_background_opacity = 0.75;

      # Editor settings
      editor = {
        font_family = "Fira Code Mono";
        font_features = {
          calt = true; # Enable font ligatures
        };
        font_size = 14;

        # Format on save and type
        format_on_save = "on";
        format_on_type = true;

        # Code actions on save
        code_actions_on_format = {
          source.organizeImports = true;
          source.fixAll = true;
        };

        # Indentation
        tab_size = 2;
        indent_guides = {
          enabled = true;
          coloring = "indent_aware";
        };

        # Whitespace and rulers
        show_whitespaces = "all";
        rulers = [79 88 100];

        # Auto-save
        auto_save = "on_focus_change";

        # Scrolling
        scroll_beyond_last_line = "one_page";

        # Bracket matching
        match_brackets = true;

        # File handling
        ensure_final_newline_on_save = true;
        remove_trailing_whitespace_on_save = true;

        # Hover behavior
        hover_popover_enabled = true;

        # Git integration
        git = {
          git_gutter = "tracked_files";
          inline_blame = {
            enabled = true;
            delay_ms = 800;
          };
        };

        # Completion
        completion_documentation_secondary_query_debounce = 300;
        show_completion_documentation = true;

        # Cursor
        cursor_blink = false;

        # Line numbers
        gutter = {
          line_numbers = true;
          code_actions = true;
          folds = true;
        };

        # Soft wrap
        soft_wrap = "editor_width";

        # Multi-cursor
        multi_cursor_modifier = "cmd_or_ctrl";
      };

      # File settings
      file_scan_exclusions = [
        "**/.git"
        "**/.direnv"
        "**/result"
        "**/target"
        "**/node_modules"
        "**/dist"
        "**/build"
        "**/.DS_Store"
        "**/*.pyc"
      ];

      # Language-specific settings
      languages = {
        Nix = {
          language_servers = ["nixd"];
          formatter = {
            external = {
              command = "${pkgs.alejandra}/bin/alejandra";
              arguments = [];
            };
          };
          format_on_save = "on";
          tab_size = 2;
        };

        Python = {
          language_servers = ["pyright"];
          formatter = {
            external = {
              command = "${pkgs.black}/bin/black";
              arguments = ["-"];
            };
          };
          format_on_save = "on";
          tab_size = 4;
        };

        Rust = {
          language_servers = ["rust-analyzer"];
          format_on_save = "on";
          tab_size = 4;
        };

        "C++" = {
          language_servers = ["clangd"];
          format_on_save = "on";
          tab_size = 2;
        };

        C = {
          language_servers = ["clangd"];
          format_on_save = "on";
          tab_size = 2;
        };

        YAML = {
          tab_size = 2;
          format_on_save = "on";
        };

        JSON = {
          tab_size = 2;
          format_on_save = "on";
        };

        Typst = {
          tab_size = 2;
          format_on_save = "on";
        };

        Markdown = {
          language_servers = ["marksman"];
          tab_size = 2;
          format_on_save = "on";
        };

        Diff = {
          tab_size = 2;
          format_on_save = "off";
        };
      };

      # Terminal settings
      terminal = {
        shell = {
          program = "${pkgs.fish}/bin/fish";
        };
        working_directory = "current_project_directory";
        blinking = "terminal_controlled";
        alternate_scroll = "off";
        copy_on_select = false;
        scrollback_lines = 10000;
      };

      # Git settings
      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          enabled = true;
          delay_ms = 800;
        };
      };

      # Project panel
      project_panel = {
        button = true;
        default_width = 240;
        dock = "left";
        file_icons = true;
        folder_icons = true;
        git_status = true;
        indent_size = 20;
        auto_reveal_entries = true;
        auto_fold_dirs = true;
      };

      # Outline panel
      outline_panel = {
        button = true;
        default_width = 300;
        dock = "right";
        file_icons = true;
        folder_icons = true;
        indent_size = 20;
      };

      # Collaboration panel
      collaboration_panel = {
        button = false;
        dock = "left";
        default_width = 240;
      };

      # Chat panel
      chat_panel = {
        button = false;
        dock = "right";
        default_width = 240;
      };

      # Notification panel
      notification_panel = {
        button = true;
        dock = "right";
        default_width = 380;
      };

      # Assistant settings
      assistant = {
        enabled = true;
        version = "2";
        default_model = {
          provider = "copilot_chat";
          model = "gpt-4";
        };
        dock = "right";
        default_width = 640;
        button = true;
      };

      # Search settings
      search = {
        whole_word = false;
        case_sensitive = false;
        include_ignored = false;
        regex = false;
      };

      # UI settings
      ui_font_size = 24;
      ui_font_family = "Zed Sans";
      buffer_font_size = 24;
      buffer_font_family = "Fira Code Mono";

      # Window settings
      auto_update = false; # Managed by Nix
      restore_on_startup = "none"; # Skip welcome page
      confirm_quit = false;

      # Performance settings (NixOS optimized)
      use_autoclose = true;
      cursor_blink = false;
      show_call_status_icon = true;

      # Enhanced performance for NixOS
      enable_language_server = true;
      show_completions_on_input = true;
      use_on_type_format = false; # Can be resource intensive on large files

      # Vim mode settings
      vim_mode = true;

      # Telemetry (completely disabled)
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # Toolbar
      toolbar = {
        breadcrumbs = true;
        quick_actions = true;
      };

      # Tabs
      tabs = {
        close_position = "right";
        file_icons = true;
        git_status = true;
      };

      # Scrollbar
      scrollbar = {
        show = "auto";
        git_diff = true;
        search_results = true;
        selected_symbol = true;
        diagnostics = true;
      };

      # Inlay hints
      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        edit_debounce_ms = 700;
        scroll_debounce_ms = 50;
      };

      # Copilot settings
      features = {
        copilot = true;
      };

      # Auto-install extensions
      auto_install_extensions = {
        nix = true;
        python = true;
        rust = true;
        cpp = true;
        yaml = true;
        dockerfile = true;
        prettier = true;
        markdownlint = true;
        toml = true;
        typst = true;
        html = true;
        css = true;
        json = true;
        fish = true;
      };

      # LSP settings
      lsp = {
        nixd = {
          binary = {
            path = "${pkgs.nixd}/bin/nixd";
          };
          settings = {
            nixd = {
              formatting = {
                command = ["alejandra"];
                timeout_ms = 5000;
              };
              options = {
                enable = true;
                target = ["all"];
                offline = true;
                nixos = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString /home/${config.home.username}/.config/nixos)).nixosConfigurations.p620.options";
                };
                home_manager = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString /home/${config.home.username}/.config/nixos)).homeConfigurations.\"${config.home.username}@p620\".options";
                };
              };
              diagnostics = {
                enable = true;
                ignored = [];
                excluded = [
                  "\\.direnv"
                  "result"
                  "\\.git"
                  "node_modules"
                ];
              };
              eval = {
                depth = 2;
                workers = 3;
              };
              completion = {
                enable = true;
                priority = 10;
              };
            };
          };
        };

        rust-analyzer = {
          binary = {
            path = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          };
          settings = {
            "rust-analyzer" = {
              checkOnSave = true;
              check = {
                command = "check";
              };
            };
          };
        };

        pyright = {
          binary = {
            path = "${pkgs.pyright}/bin/pyright";
          };
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic";
                autoImportCompletions = true;
              };
            };
          };
        };

        clangd = {
          binary = {
            path = "${pkgs.clang-tools}/bin/clangd";
          };
          settings = {
            clangd = {
              fallbackFlags = ["-std=c++17"];
              compilationDatabasePath = "./";
            };
          };
        };

        marksman = {
          binary = {
            path = "${pkgs.marksman}/bin/marksman";
          };
        };
      };
    };
  };

  # Set up XDG file associations for Zed (uses system-provided desktop entry)
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "text/plain" = ["zed.desktop"];
      "text/markdown" = ["zed.desktop"];
      "application/json" = ["zed.desktop"];
      "application/x-yaml" = ["zed.desktop"];
      "text/x-python" = ["zed.desktop"];
      "text/x-csrc" = ["zed.desktop"];
      "text/x-c++src" = ["zed.desktop"];
      "text/x-chdr" = ["zed.desktop"];
      "text/x-c++hdr" = ["zed.desktop"];
      "text/x-shellscript" = ["zed.desktop"];
      "text/html" = ["zed.desktop"];
      "text/css" = ["zed.desktop"];
      "text/javascript" = ["zed.desktop"];
    };
  };
}
