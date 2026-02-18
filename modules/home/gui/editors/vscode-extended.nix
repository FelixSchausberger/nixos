{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.features.development.enable or config.hostConfig.isGui) {
    programs.vscode.profiles.default.userSettings = {
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
    };
  };
}
