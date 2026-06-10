{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.features.development.enable or config.hostConfig.isGui) {
    programs.zed-editor = {
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
        prettier

        # Additional tools
        claude-code
      ];

      userSettings = {
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
                # Options configuration removed to fix builtins.toFile warnings
                # These provide option completion in nixd but are optional
                # The configuration referenced non-existent host "p620" and caused evaluation warnings
                # Users can add host-specific options configuration if needed
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
  };
}
