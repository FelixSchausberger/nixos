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
    clippy # Bunch of lints to catch common mistakes and improve your Rust code
    # helix-gpt
    lsp-ai # Open-source language server that serves as a backend for AI-powered functionality
    markdown-oxide # Markdown LSP server inspired by Obsidian
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

      # https://github.com/mhersson/mpls
      mpls = {
        command = "mpls";
        args = ["--dark-mode", "--enable-emoji"];
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
        auto-format = true;
      }
      {
        name = "nix";
        auto-format = true;
        file-types = ["nix"];
        formatter.command = "alejandra";
        language-servers = ["lsp-ai"];
      }
      {
        name = "markdown";
        auto-format = true;
        # formatter.command = "dprint fmt --stdin md";
        formatter = {
          command = "dprint";
          args = ["fmt --stdin md"];
        };
        language-servers = [
          "markdown-oxide"
          "mpls"
        ];
        rulers = [
          120
        ];
      }
      {
        name = "python";
        auto-format = true;
      }
      {
        name = "rust";
        auto-format = true;
        formatter.command = "clippy";
        language-servers = [
          "gpt"
        ];
      }
      {
        name = "toml";
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
        auto-format = true;
      }
      {
        name = "yaml";
        auto-format = true;
      }
    ];
  };
}
