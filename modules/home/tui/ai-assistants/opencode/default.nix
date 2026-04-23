{
  pkgs,
  config,
  lib,
  ...
}: let
  sharedBehaviors = config.ai-assistants.behaviors.definitions;

  combinedRules = lib.concatStringsSep "\n\n---\n\n" (
    lib.mapAttrsToList (_name: behavior: "# ${behavior.description}\n\n${behavior.content}") (
      lib.filterAttrs (_n: v: v.enabled) sharedBehaviors
    )
  );

  sharedSkills = ../skills;
in {
  programs.opencode = {
    enable = true;

    package = pkgs.symlinkJoin {
      name = "opencode-wrapped";
      paths = [pkgs.opencode];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
          --set NODE_TLS_REJECT_UNAUTHORIZED "0"
      '';
      meta.mainProgram = "opencode";
    };

    # Enable programs.mcp integration - HM module correctly transforms command+args+env
    enableMcpIntegration = true;

    # Make MCP server packages available on PATH for opencode's MCP runtime
    extraPackages = with pkgs; [
      github-mcp-server
      mcp-nixos
      mcp-language-server
      # Formatters
      nixfmt
      rustfmt
      taplo
    ];

    # Use shared behaviors as global rules/instructions
    context = combinedRules;

    # Skills shared between opencode and claude-code
    skills = sharedSkills;

    settings = {
      model = "ollama-cloud/minimax-m2.7";
      small_model = "ollama-cloud/minimax-m2.7";
      agent = {
        plan.model = "ollama-cloud/glm-5.1";
        build.model = "ollama-cloud/minimax-m2.7";
      };
      plugin = [
        "opencode-code-simplifier"
        "opencode-notify"
        "@slkiser/opencode-quota"
      ];
      permission = {
        bash = {
          "git reset*" = "deny";
          "git push --force*" = "deny";
          "git push -f *" = "deny";
          "git rebase*" = "deny";
          "git commit*" = "deny";
          "git stash*" = "deny";
          "git checkout * -- *" = "deny";
        };
      };
      formatter = {
        nixfmt = {};
        rustfmt = {};
        taplo = {
          command = [
            "taplo"
            "fmt"
            "$FILE"
          ];
          extensions = [".toml"];
        };
      };
    };

    # Use built-in web service
    web = {
      enable = true;
      extraArgs = [
        "--port"
        "4096"
        "--hostname"
        "0.0.0.0"
        "--mdns"
      ];
    };

    # TUI sidebar for opencode-quota plugin
    tui = {
      plugin = ["@slkiser/opencode-quota"];
    };
  };

  # Set API keys as environment variables for MCP servers and Ollama
  home.sessionVariables = {
    GITHUB_TOKEN = config.sops.secrets."github/token".path;
    OLLAMA_API_KEY = config.sops.secrets."ollama/api-key".path;
  };

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
