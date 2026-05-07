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
      model = "github-copilot/claude-sonnet-4.6";
      small_model = "github-copilot/claude-sonnet-4.6";
      agent = {
        plan.model = "github-copilot/claude-sonnet-4.6";
        build.model = "github-copilot/gpt-5.3-codex";
      };
      plugin = ["@slkiser/opencode-quota"];
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

  xdg.configFile."opencode/plugins/zellij-attention.js".text = ''
    export const ZellijAttentionPlugin = async ({ $ }) => {
      const paneId = process.env.ZELLIJ_PANE_ID;

      if (!paneId) {
        return {};
      }

      const notifyAttention = async (state) => {
        try {
          await $`zellij pipe --name "zellij-attention::''${state}::''${paneId}"`;
        } catch {
          // Ignore if zellij isn't available in this process context.
        }
      };

      const notifySmartTabs = async (status, onFocus = null) => {
        const payload = JSON.stringify({
          pane_id: paneId,
          status,
          ...(onFocus ? { on_focus: onFocus } : {}),
        });

        try {
          await $`zellij pipe --name pane_status --plugin smart-tabs -- ''${payload}`;
        } catch {
          // Ignore if zellij isn't available in this process context.
        }
      };

      return {
        event: async ({ event }) => {
          if (event.type === "permission.asked") {
            await notifyAttention("waiting");
            await notifySmartTabs("pending", "idle");
          }

          if (
            event.type === "permission.replied" ||
            event.type === "session.idle" ||
            event.type === "session.error"
          ) {
            await notifyAttention("completed");
            await notifySmartTabs("done", "idle");
          }
        },
      };
    };
  '';

  xdg.configFile."opencode/agents/code-simplifier.md".text = ''
    ---
    description: Simplifies recently modified code while preserving exact behavior
    mode: subagent
    model: github-copilot/claude-sonnet-4.6
    permission:
      edit: allow
      bash: deny
    ---

    You are a code simplification specialist.

    Simplify recently modified code for clarity, consistency, and maintainability while preserving exact functionality.

    Rules:
    - Never change behavior, side effects, or outputs.
    - Prefer explicit readable code over compact clever code.
    - Reduce avoidable nesting and duplicated logic.
    - Remove obvious comments and stale debug artifacts.
    - Prefer if/else or switch over nested ternaries.
    - Keep useful abstractions; do not collapse structure just to reduce line count.

    Scope:
    - Focus on files touched in the current change unless the user asks for broader refactoring.

    Workflow:
    1. Identify touched code paths.
    2. Apply small, behavior-preserving simplifications.
    3. Keep naming consistent with repository conventions.
    4. Validate that semantics are unchanged.
    5. Report meaningful simplifications only.
  '';

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
