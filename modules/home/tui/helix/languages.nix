{pkgs, ...}: let
  defineModel = name: {
    model,
    completion ? {},
  }: {
    model.${name} = model;
    completion =
      completion
      // {
        model = name;
      };
  };
  model1 = defineModel "model1" {
    model = {
      type = "ollama";
      model = "qwen2.5-coder:1.5b";
    };
    completion = {
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
in {
  home.packages = with pkgs; [
    alejandra # Uncompromising Nix Code Formatter
    # helix-gpt
    lsp-ai # Open-source language server that serves as a backend for AI-powered functionality

    # Language servers
    clang-tools # C/C++ tools (includes clangd)
    nodePackages.typescript-language-server # TypeScript/JavaScript LSP
    nodePackages.vscode-langservers-extracted # HTML/CSS/JSON LSPs
    yaml-language-server # YAML LSP
    nodePackages.bash-language-server # Bash LSP
    python312Packages.python-lsp-server # Python LSP
    lua-language-server # Lua LSP
    tinymist # Typst LSP
    gopls # Go language server
    dockerfile-language-server # Docker LSP
    docker-compose-language-service # Docker Compose LSP
    fish-lsp # Fish language server

    # Debuggers
    lldb # LLDB debugger (includes lldb-dap)

    # Formatters
    nodePackages.prettier # Use development shell version to avoid conflicts
    black # Python formatter
    taplo # TOML formatter
    shfmt # Shell script formatter
    stylua # Lua formatter
    fish # Fish shell (includes fish_indent formatter)
    gofumpt # Go formatter (stricter than gofmt)
    yamlfmt # YAML formatter
  ];

  programs.helix.languages = {
    # the language-server option currently requires helix from the master branch at https://github.com/helix-editor/helix/
    language-server = {
      # gpt = {
      #   command = "${pkgs.helix-gpt}/bin/helix-gpt";
      # };

      lsp-ai = {
        command = "lsp-ai";
        config = {
          memory.file_store = {};
          models = model1.model;
          inherit (model1) completion;
        };
      };

      markdown-oxide = {
        command = "markdown-oxide";
      };

      rust-analyzer = {
        command = "rust-analyzer";
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

    # language-server.typescript-language-server = with pkgs.nodePackages; {
    #   command = "${typescript-language-server}/bin/typescript-language-server";
    #   args = [ "--stdio" "--tsserver-path=${typescript}/lib/node_modules/typescript/lib" ];
    #   language-id = "javascript";
    # };

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
        language-servers = ["lsp-ai"];
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
        name = "toml";
        scope = "source.toml";
        file-types = ["toml"];
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt --stdin toml"];
        };
      }
      # {
      #   name = "typescript";
      #   language-servers = [
      #       "ts",
      #       "gpt"
      #   ];
      # }
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
      # Jujutsu config files (already supported via TOML)
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
