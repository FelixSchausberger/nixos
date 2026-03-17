{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkIf (config.features.development.enable or config.hostConfig.isGui or false) (with pkgs; [
    # Development language servers
    clang-tools # C/C++ tools (includes clangd)
    nodePackages.typescript-language-server # TypeScript/JavaScript LSP
    nodePackages.vscode-langservers-extracted # HTML/CSS/JSON LSPs
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
    nodePackages.prettier # Use development shell version to avoid conflicts
    black # Python formatter
    stylua # Lua formatter
    fish # Fish shell (includes fish_indent formatter)
    gofumpt # Go formatter (stricter than gofmt)
  ]);

  programs.helix.languages = lib.mkIf (config.features.development.enable or config.hostConfig.isGui or false) {
    language-server = {
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
