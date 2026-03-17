{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra # Uncompromising Nix Code Formatter
    lsp-ai # Open-source language server that serves as a backend for AI-powered functionality

    # Core language servers
    nodePackages.vscode-langservers-extracted # HTML/CSS/JSON LSPs
    yaml-language-server # YAML LSP
    nodePackages.bash-language-server # Bash LSP

    # Core formatters
    shfmt # Shell script formatter
    taplo # TOML formatter
    yamlfmt # YAML formatter
  ];

  programs.helix.languages = {
    language-server = {
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
    ];
  };
}
