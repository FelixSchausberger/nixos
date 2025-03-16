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
        formatter.command = "${pkgs.alejandra}/bin/alejandra";
        language-servers = ["lsp-ai"];
      }
      {
        name = "markdown";
        auto-format = true;
      }
      {
        name = "python";
        auto-format = true;
      }
      {
        name = "rust";
        auto-format = true;
        formatter.command = "${pkgs.clippy}/bin/clippy";
        language-servers = [
          "gpt"
        ];
      }
      {
        name = "toml";
        auto-format = true;
        formatter.command = "${pkgs.taplo}/bin/taplo fmt";
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
