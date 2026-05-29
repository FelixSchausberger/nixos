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

    extraPackages = with pkgs; [
      github-mcp-server
      mcp-nixos
      mcp-language-server
      # Formatters
      nixfmt
      rustfmt
      taplo
    ];

    context = combinedRules;

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

    tui = {
      plugin = ["@slkiser/opencode-quota"];
    };
  };

  # Set API keys from sops secrets at login time
  # home.sessionVariables can't read file contents — it stores the secret path string
  programs.fish.loginShellInit = ''
    if test -f ${config.sops.secrets."github/token".path}
      set -gx GITHUB_TOKEN (cat ${config.sops.secrets."github/token".path})
    end
    if test -f ${config.sops.secrets."ollama/api-key".path}
      set -gx OLLAMA_API_KEY (cat ${config.sops.secrets."ollama/api-key".path})
    end
  '';

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

      return {
        event: async ({ event }) => {
          if (event.type === "permission.asked") {
            await notifyAttention("waiting");
          }

          if (
            event.type === "permission.replied" ||
            event.type === "session.idle" ||
            event.type === "session.error"
          ) {
            await notifyAttention("completed");
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

  # Ensure opencode's AGENTS.md always includes the jjwork rule
  # This is appended to the auto-generated file on activation
  home.activation.opencode-agents = lib.mkAfter ''
        AGENTS_FILE="$HOME/.config/opencode/AGENTS.md"
        if [ -f "$AGENTS_FILE" ] && ! grep -q "jjwork" "$AGENTS_FILE"; then
          cat >> "$AGENTS_FILE" << 'AGENTS_EOF'


    ---

    # Prevents working copy divergence (critical workflow rule)

    CRITICAL: Always rebase the working copy onto main before starting any work.

    Before making any changes, run:
    ```bash
    jjwork
    ```
    This fetches from remote, rebases onto main, and creates a clean empty commit.

    This prevents the working copy from diverging into orphan branches that create messy merge histories and lost files. Every opencode session MUST start with `jjwork`.
    AGENTS_EOF
        fi
  '';

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
