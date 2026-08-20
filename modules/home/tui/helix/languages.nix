{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  # Core language servers and formatters (always available).
  # Extended language servers and formatters (only when development is enabled).
  # Combined into one mkMerge to avoid setting home.packages twice in the same module.
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

    (lib.mkIf (config.features.development.enable or config.hostConfig.isGui or false) (with pkgs; [
      # Development language servers
      clang-tools # C/C++ tools (includes clangd)
      typescript-language-server # TypeScript/JavaScript LSP
      vscode-langservers-extracted # HTML/CSS/JSON LSPs
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

  # Single program.nhx.languages definition — nhx uses the deprecated
  # `types.attrs` type for this option, which cannot be merged across
  # multiple modules (shallow `//` merge drops one definition entirely).
  # Keeping all language configs here avoids the merge issue.
  programs.nhx.languages = {
    language-server = {
      # Core
      lsp-ai = {
        command = "lsp-ai";
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
        command = "jj-lsp";
      };

      markdown-oxide = {
        command = "markdown-oxide";
      };

      vscode-json-language-server = {
        command = "vscode-json-language-server";
        args = ["--stdio"];
      };

      yaml-language-server = {
        command = "yaml-language-server";
        args = ["--stdio"];
      };

      bash-language-server = {
        command = "bash-language-server";
        args = ["start"];
      };

      # Extended — rust-analyzer uses the Nix store path directly to
      # bypass the rustup proxy (which creates an infinite recursion
      # loop when rust-analyzer is not installed as a rustup component).
      rust-analyzer = {
        command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        config = {
          checkOnSave = {
            command = "clippy";
          };
        };
      };

      clangd = {
        command = "clangd";
      };

      typescript-language-server = {
        command = "typescript-language-server";
        args = ["--stdio"];
      };

      vscode-html-language-server = {
        command = "vscode-html-language-server";
        args = ["--stdio"];
      };

      vscode-css-language-server = {
        command = "vscode-css-language-server";
        args = ["--stdio"];
      };

      pylsp = {
        command = "pylsp";
      };

      lua-language-server = {
        command = "lua-language-server";
      };

      tinymist = {
        command = "tinymist";
      };

      gopls = {
        command = "gopls";
      };

      docker-langserver = {
        command = "docker-langserver";
        args = ["--stdio"];
      };

      docker-compose-langserver = {
        command = "docker-compose-langserver";
        args = ["--stdio"];
      };

      fish-lsp = {
        command = "fish-lsp";
        args = ["start"];
      };
    };

    debugger = {
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

    language = [
      {
        name = "bash";
        scope = "source.bash";
        file-types = [
          "sh"
          "bash"
          "zsh"
        ];
        auto-format = true;
        formatter.command = "shfmt";
        language-servers = ["bash-language-server"];
      }
      {
        name = "nix";
        scope = "source.nix";
        auto-format = true;
        file-types = ["nix"];
        formatter.command = "alejandra";
        language-servers = ["lsp-ai" "jj-lsp"];
      }
      {
        name = "markdown";
        scope = "source.markdown";
        file-types = [
          "md"
          "markdown"
        ];
        auto-format = true;
        soft-wrap.enable = true;
        formatter = {
          command = "dprint";
          args = [
            "fmt"
            "--stdin"
            "md"
          ];
        };
        language-servers = [
          "markdown-oxide"
        ];
        rulers = [120];
        text-width = 120;
      }
      {
        name = "toml";
        scope = "source.toml";
        file-types = ["toml"];
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt --stdin toml"];
        };
      }
      {
        name = "json";
        scope = "source.json";
        file-types = ["json"];
        auto-format = true;
        formatter.command = "prettier";
        formatter.args = [
          "--parser"
          "json"
        ];
        language-servers = ["vscode-json-language-server"];
      }
      {
        name = "yaml";
        scope = "source.yaml";
        file-types = [
          "yaml"
          "yml"
        ];
        auto-format = true;
        formatter.command = "yamlfmt";
        language-servers = ["yaml-language-server"];
      }
      {
        name = "vim";
        scope = "source.viml";
        file-types = [
          "vim"
          "vimrc"
        ];
        auto-format = false;
      }
      {
        name = "git-commit";
        scope = "text.git-commit";
        file-types = ["COMMIT_EDITMSG"];
        rulers = [
          50
          72
        ];
        text-width = 72;
      }
      {
        name = "git-rebase";
        scope = "text.git-rebase";
        file-types = ["git-rebase-todo"];
        auto-format = false;
      }
      {
        name = "jjdescription";
        scope = "text.jjdescription";
        file-types = ["jjdescription"];
        rulers = [
          50
          72
        ];
        text-width = 72;
      }
      {
        name = "python";
        scope = "source.python";
        file-types = [
          "py"
          "pyi"
          "py3"
          "pyw"
          "ptl"
        ];
        auto-format = true;
        formatter.command = "black";
        language-servers = ["pylsp"];
      }
      {
        name = "rust";
        scope = "source.rust";
        file-types = ["rs"];
        auto-format = true;
        formatter.command = "rustfmt";
        language-servers = [
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
        file-types = ["typ"];
        auto-format = true;
        language-servers = ["tinymist"];
      }
      {
        name = "c";
        scope = "source.c";
        file-types = [
          "c"
          "h"
        ];
        auto-format = true;
        language-servers = ["clangd"];
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
        file-types = [
          "cpp"
          "cc"
          "cxx"
          "c++"
          "hpp"
          "hh"
          "hxx"
          "h++"
        ];
        auto-format = true;
        language-servers = ["clangd"];
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
        file-types = [
          "js"
          "jsx"
          "mjs"
        ];
        auto-format = true;
        formatter.command = "prettier";
        formatter.args = [
          "--parser"
          "babel"
        ];
        language-servers = ["typescript-language-server"];
      }
      {
        name = "typescript";
        scope = "source.ts";
        file-types = [
          "ts"
          "tsx"
        ];
        auto-format = true;
        formatter.command = "prettier";
        formatter.args = [
          "--parser"
          "typescript"
        ];
        language-servers = ["typescript-language-server"];
      }
      {
        name = "html";
        scope = "text.html.basic";
        file-types = [
          "html"
          "htm"
        ];
        auto-format = true;
        formatter.command = "prettier";
        formatter.args = [
          "--parser"
          "html"
        ];
        language-servers = ["vscode-html-language-server"];
      }
      {
        name = "css";
        scope = "source.css";
        file-types = ["css"];
        auto-format = true;
        formatter.command = "prettier";
        formatter.args = [
          "--parser"
          "css"
        ];
        language-servers = ["vscode-css-language-server"];
      }
      {
        name = "fish";
        scope = "source.fish";
        file-types = ["fish"];
        auto-format = true;
        formatter.command = "fish_indent";
        language-servers = ["fish-lsp"];
      }
      {
        name = "lua";
        scope = "source.lua";
        file-types = ["lua"];
        auto-format = true;
        formatter.command = "stylua";
        formatter.args = [
          "--stdin-filepath"
          "file.lua"
          "-"
        ];
        language-servers = ["lua-language-server"];
      }
      {
        name = "go";
        scope = "source.go";
        file-types = ["go"];
        auto-format = true;
        formatter.command = "gofumpt";
        language-servers = ["gopls"];
      }
      {
        name = "dockerfile";
        scope = "source.dockerfile";
        file-types = [
          "Dockerfile"
          "dockerfile"
        ];
        auto-format = false;
        language-servers = ["docker-langserver"];
      }
      {
        name = "hyprlang";
        scope = "source.hyprlang";
        file-types = ["conf"];
        auto-format = false;
        comment-token = "#";
      }
      {
        name = "bass";
        scope = "source.bass";
        file-types = ["bass"];
        auto-format = false;
        comment-token = "#";
      }
    ];
  };
}
