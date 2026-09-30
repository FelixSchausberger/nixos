{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;

  # Extended language servers and formatters only ship when development is
  # enabled; the core set is always available. Both editors read this data and
  # install the same package set, so they stay in lockstep.
  developmentTools = config.features.development.enable or config.hostConfig.guiApps or false;

  languageServerType = types.submodule {
    options = {
      cmd = mkOption {
        type = types.listOf types.str;
        description = "Argument vector used to start the language server.";
      };
      config = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Server initialization options. Helix passes this table as the
          server's `config`, Neovim as `init_options`; both end up in the
          server's initialization handshake.
        '';
      };
    };
  };

  formatterType = types.submodule {
    options = {
      command = mkOption {
        type = types.str;
        description = "Formatter executable.";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Arguments passed to the formatter.";
      };
    };
  };

  languageType = types.submodule ({config, ...}: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Language identifier used by both editors.";
      };

      scope = mkOption {
        type = types.str;
        description = "Tree-sitter scope used by Helix for language detection.";
      };

      fileTypes = mkOption {
        type = types.listOf types.str;
        description = "File patterns Helix detects this language by (extensions or exact file names).";
      };

      filetypes = mkOption {
        type = types.listOf types.str;
        default = [config.name];
        description = "Neovim filetypes this language maps to; defaults to the language name.";
      };

      servers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Names of the language servers (keys of editors.languageServers) that handle this language.";
      };

      autoFormat = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether to format on save. Null omits Helix's auto-format key and keeps its default.";
      };

      formatter = mkOption {
        type = types.nullOr formatterType;
        default = null;
        description = "Formatter used on save when auto-format is enabled.";
      };

      rulers = mkOption {
        type = types.nullOr (types.listOf types.int);
        default = null;
        description = "Column rulers (Helix only).";
      };

      textWidth = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Text width used for wrapping and formatting (Helix only).";
      };

      softWrap = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether to soft-wrap this language (Helix only).";
      };

      commentToken = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Comment token (Helix only).";
      };

      debugger = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Debugger configuration for this language, in Helix's debugger template shape.";
      };
    };
  });
in {
  options.editors = {
    languageServers = mkOption {
      type = types.attrsOf languageServerType;
      default = {};
      description = "Language servers shared by Helix and Neovim, keyed by server name.";
    };

    languages = mkOption {
      type = types.listOf languageType;
      default = [];
      description = "Per-language configuration shared by Helix and Neovim, in display order.";
    };

    debuggers = mkOption {
      type = types.attrs;
      default = {};
      description = "Debugger templates shared by Helix and Neovim, keyed by debugger name.";
    };
  };

  config = {
    editors.languageServers = {
      lsp-ai = {
        cmd = ["lsp-ai"];
        config = {
          memory.file_store = {};
          models = {
            model1 = {
              type = "ollama";
              model = "qwen2.5-coder:1.5b";
            };
          };
          completion = {
            model = "model1";
            parameters = {
              max_context = 2048;
              options.num_predict = 32;
              fim = {
                start = "<|fim_prefix|>";
                middle = "<|fim_suffix|>";
                end = "<|fim_middle|>";
              };
            };
          };
        };
      };

      jj-lsp = {
        cmd = ["jj-lsp"];
      };

      markdown-oxide = {
        cmd = ["markdown-oxide"];
      };

      vscode-json-language-server = {
        cmd = [
          "vscode-json-language-server"
          "--stdio"
        ];
      };

      yaml-language-server = {
        cmd = [
          "yaml-language-server"
          "--stdio"
        ];
      };

      bash-language-server = {
        cmd = [
          "bash-language-server"
          "start"
        ];
      };

      # rust-analyzer uses the Nix store path directly so it does not depend
      # on any toolchain's rust-analyzer component.
      rust-analyzer = {
        cmd = ["${pkgs.rust-analyzer}/bin/rust-analyzer"];
        config = {
          # Diagnostics on save run clippy: checkOnSave is the boolean enable
          # flag, the command lives at check.command.
          check.command = "clippy";
        };
      };

      clangd = {
        cmd = ["clangd"];
      };

      typescript-language-server = {
        cmd = [
          "typescript-language-server"
          "--stdio"
        ];
      };

      vscode-html-language-server = {
        cmd = [
          "vscode-html-language-server"
          "--stdio"
        ];
      };

      vscode-css-language-server = {
        cmd = [
          "vscode-css-language-server"
          "--stdio"
        ];
      };

      pylsp = {
        cmd = ["pylsp"];
      };

      lua-language-server = {
        cmd = ["lua-language-server"];
      };

      tinymist = {
        cmd = ["tinymist"];
      };

      gopls = {
        cmd = ["gopls"];
      };

      docker-langserver = {
        cmd = [
          "docker-langserver"
          "--stdio"
        ];
      };

      docker-compose-langserver = {
        cmd = [
          "docker-compose-langserver"
          "--stdio"
        ];
      };

      fish-lsp = {
        cmd = [
          "fish-lsp"
          "start"
        ];
      };
    };

    editors.debuggers = {
      lldb-dap = {
        command = "lldb-dap";
        transport = "stdio";
        name = "lldb-dap";
        templates = [
          {
            name = "binary";
            request = "launch";
            completion = [
              {
                completion = "filename";
                name = "binary";
              }
            ];
            args = {
              program = "{0}";
            };
          }
        ];
      };
    };

    editors.languages = [
      {
        name = "bash";
        scope = "source.bash";
        fileTypes = [
          "sh"
          "bash"
          "zsh"
        ];
        filetypes = [
          "sh"
          "bash"
          "zsh"
        ];
        autoFormat = true;
        formatter.command = "shfmt";
        servers = ["bash-language-server"];
      }
      {
        name = "nix";
        scope = "source.nix";
        fileTypes = ["nix"];
        autoFormat = true;
        formatter.command = "alejandra";
        servers = [
          "lsp-ai"
          "jj-lsp"
        ];
      }
      {
        name = "markdown";
        scope = "source.markdown";
        fileTypes = [
          "md"
          "markdown"
        ];
        autoFormat = true;
        softWrap = true;
        formatter = {
          command = "dprint";
          args = [
            "fmt"
            "--stdin"
            "md"
          ];
        };
        servers = ["markdown-oxide"];
        rulers = [120];
        textWidth = 120;
      }
      {
        name = "toml";
        scope = "source.toml";
        fileTypes = ["toml"];
        autoFormat = true;
        formatter = {
          command = "dprint";
          args = [
            "fmt"
            "--stdin"
            "toml"
          ];
        };
      }
      {
        name = "json";
        scope = "source.json";
        fileTypes = ["json"];
        autoFormat = true;
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "json"
          ];
        };
        servers = ["vscode-json-language-server"];
      }
      {
        name = "yaml";
        scope = "source.yaml";
        fileTypes = [
          "yaml"
          "yml"
        ];
        autoFormat = true;
        formatter.command = "yamlfmt";
        servers = ["yaml-language-server"];
      }
      {
        name = "vim";
        scope = "source.viml";
        fileTypes = [
          "vim"
          "vimrc"
        ];
        autoFormat = false;
      }
      {
        name = "git-commit";
        scope = "text.git-commit";
        fileTypes = ["COMMIT_EDITMSG"];
        filetypes = ["gitcommit"];
        rulers = [
          50
          72
        ];
        textWidth = 72;
      }
      {
        name = "git-rebase";
        scope = "text.git-rebase";
        fileTypes = ["git-rebase-todo"];
        filetypes = ["gitrebase"];
        autoFormat = false;
      }
      {
        name = "jjdescription";
        scope = "text.jjdescription";
        fileTypes = ["jjdescription"];
        rulers = [
          50
          72
        ];
        textWidth = 72;
      }
      {
        name = "python";
        scope = "source.python";
        fileTypes = [
          "py"
          "pyi"
          "py3"
          "pyw"
          "ptl"
        ];
        autoFormat = true;
        formatter.command = "black";
        servers = ["pylsp"];
      }
      {
        name = "rust";
        scope = "source.rust";
        fileTypes = ["rs"];
        autoFormat = true;
        formatter.command = "rustfmt";
        servers = [
          "rust-analyzer"
          "lsp-ai"
          "jj-lsp"
        ];
        debugger = {
          name = "lldb-dap";
          transport = "stdio";
          command = "lldb-dap";
          templates = [
            {
              name = "binary";
              request = "launch";
              completion = [
                {
                  completion = "filename";
                  name = "binary";
                }
              ];
              args = {
                program = "{0}";
              };
            }
          ];
        };
      }
      {
        name = "typst";
        scope = "source.typst";
        fileTypes = ["typ"];
        autoFormat = true;
        servers = ["tinymist"];
      }
      {
        name = "c";
        scope = "source.c";
        fileTypes = [
          "c"
          "h"
        ];
        autoFormat = true;
        servers = ["clangd"];
        debugger = {
          name = "lldb-dap";
          transport = "stdio";
          command = "lldb-dap";
          templates = [
            {
              name = "binary";
              request = "launch";
              completion = [
                {
                  completion = "filename";
                  name = "binary";
                }
              ];
              args = {
                program = "{0}";
              };
            }
          ];
        };
      }
      {
        name = "cpp";
        scope = "source.cpp";
        fileTypes = [
          "cpp"
          "cc"
          "cxx"
          "c++"
          "hpp"
          "hh"
          "hxx"
          "h++"
        ];
        autoFormat = true;
        servers = ["clangd"];
        debugger = {
          name = "lldb-dap";
          transport = "stdio";
          command = "lldb-dap";
          templates = [
            {
              name = "binary";
              request = "launch";
              completion = [
                {
                  completion = "filename";
                  name = "binary";
                }
              ];
              args = {
                program = "{0}";
              };
            }
          ];
        };
      }
      {
        name = "javascript";
        scope = "source.js";
        fileTypes = [
          "js"
          "jsx"
          "mjs"
        ];
        filetypes = [
          "javascript"
          "javascriptreact"
        ];
        autoFormat = true;
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "babel"
          ];
        };
        servers = ["typescript-language-server"];
      }
      {
        name = "typescript";
        scope = "source.ts";
        fileTypes = [
          "ts"
          "tsx"
        ];
        filetypes = [
          "typescript"
          "typescriptreact"
        ];
        autoFormat = true;
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "typescript"
          ];
        };
        servers = ["typescript-language-server"];
      }
      {
        name = "html";
        scope = "text.html.basic";
        fileTypes = [
          "html"
          "htm"
        ];
        autoFormat = true;
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "html"
          ];
        };
        servers = ["vscode-html-language-server"];
      }
      {
        name = "css";
        scope = "source.css";
        fileTypes = ["css"];
        autoFormat = true;
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "css"
          ];
        };
        servers = ["vscode-css-language-server"];
      }
      {
        name = "fish";
        scope = "source.fish";
        fileTypes = ["fish"];
        autoFormat = true;
        formatter.command = "fish_indent";
        servers = ["fish-lsp"];
      }
      {
        name = "lua";
        scope = "source.lua";
        fileTypes = ["lua"];
        autoFormat = true;
        formatter = {
          command = "stylua";
          args = [
            "--stdin-filepath"
            "file.lua"
            "-"
          ];
        };
        servers = ["lua-language-server"];
      }
      {
        name = "go";
        scope = "source.go";
        fileTypes = ["go"];
        autoFormat = true;
        formatter.command = "gofumpt";
        servers = ["gopls"];
      }
      {
        name = "dockerfile";
        scope = "source.dockerfile";
        fileTypes = [
          "Dockerfile"
          "dockerfile"
        ];
        autoFormat = false;
        servers = ["docker-langserver"];
      }
      {
        name = "hyprlang";
        scope = "source.hyprlang";
        fileTypes = ["conf"];
        autoFormat = false;
        commentToken = "#";
      }
      {
        name = "bass";
        scope = "source.bass";
        fileTypes = ["bass"];
        autoFormat = false;
        commentToken = "#";
      }
    ];

    # Core language servers and formatters (always available).
    # Extended language servers and formatters (only when development is enabled).
    # Single mkMerge so home.packages is not set twice in the same module.
    home.packages = lib.mkMerge [
      (with pkgs;
        [
          alejandra # Uncompromising Nix Code Formatter
          lsp-ai # Open-source language server that serves as a backend for AI-powered functionality

          # Core language servers
          vscode-langservers-extracted # HTML/CSS/JSON LSPs
          yaml-language-server # YAML LSP
          bash-language-server # Bash LSP

          # Core formatters
          shfmt # Shell script formatter
          taplo # TOML formatter
          yamlfmt # YAML formatter
        ]
        ++ [
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.jj-lsp # Conflict resolution LSP for jj
        ])

      (lib.mkIf developmentTools (with pkgs; [
        # Development language servers
        clang-tools # C/C++ tools (includes clangd)
        typescript-language-server # TypeScript/JavaScript LSP
        python312Packages.python-lsp-server # Python LSP
        lua-language-server # Lua LSP
        tinymist # Typst LSP
        gopls # Go language server
        dockerfile-language-server # Docker LSP
        docker-compose-language-service # Docker Compose LSP
        fish-lsp # Fish language server

        # Debuggers
        lldb # LLDB debugger (includes lldb-dap)

        # Development formatters
        prettier # Use development shell version to avoid conflicts
        black # Python formatter
        stylua # Lua formatter
        fish # Fish shell (includes fish_indent formatter)
        gofumpt # Go formatter (stricter than gofmt)
      ]))
    ];

    # Every language must reference servers that exist; a typo would otherwise
    # silently drop the server from Neovim's inverted filetype map.
    assertions = [
      {
        assertion =
          lib.all (
            lang: lib.all (server: config.editors.languageServers ? ${server}) lang.servers
          )
          config.editors.languages;
        message = "editors.languages: a language references an undefined entry of editors.languageServers";
      }
    ];
  };
}
