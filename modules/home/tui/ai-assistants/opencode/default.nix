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

  # Fixed port of the long-lived shared server. Local TUIs attach to it via the
  # `oc` fish function instead of spawning throwaway servers, so TUI and web UI
  # share one session store.
  webPort = 4096;
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
      alejandra
      rustfmt
      taplo
    ];

    context = combinedRules;

    skills = sharedSkills;

    settings = {
      model = "github-copilot/gpt-5-mini";
      small_model = "github-copilot/gpt-5-mini";
      agent = {
        explore.model = "github-copilot/gpt-5-mini";
        general.model = "github-copilot/gpt-5-mini";
        title.model = "github-copilot/gpt-5-mini";
        summary.model = "github-copilot/gpt-5-mini";
        compaction.model = "github-copilot/gpt-5-mini";
      };
      plugin = ["@slkiser/opencode-quota" "@mohak34/opencode-notifier"];
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
        (toString webPort)
        # Loopback only: remote access goes through Tailscale Serve (TLS,
        # tailnet-only). See modules/system/homelab/opencode-web.nix.
        "--hostname"
        "127.0.0.1"
      ];
    };

    tui = {
      plugin = ["@slkiser/opencode-quota" "@mohak34/opencode-notifier"];
    };
  };

  # Attach a TUI client to the shared server instead of letting bare `opencode`
  # start its own throwaway instance. Attaching keeps sessions visible in and
  # controllable from both the TUI here and the web UI on other devices.
  programs.fish.functions.oc = {
    description = "Attach to the shared opencode server (same sessions as the web UI)";
    body = ''
      opencode attach "http://127.0.0.1:${toString webPort}" $argv
    '';
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

  xdg.configFile."opencode/agents/code-simplifier.md".text = ''
    ---
    description: Simplifies recently modified code while preserving exact behavior
    mode: subagent
    model: github-copilot/gpt-5-mini
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

  xdg.configFile."opencode/opencode-notifier.json".text = builtins.toJSON {
    sound = true;
    notification = true;
    suppressWhenFocused = false;
    bell = false;
    timeout = 5;
    showProjectName = true;
    showSessionTitle = false;
    showIcon = true;
    linux = {
      grouping = true;
    };
    events = {
      permission = {
        sound = true;
        notification = true;
      };
      complete = {
        sound = true;
        notification = true;
      };
      error = {
        sound = true;
        notification = true;
      };
      question = {
        sound = true;
        notification = true;
      };
      subagent_complete = {
        sound = false;
        notification = false;
      };
      user_cancelled = {
        sound = false;
        notification = false;
      };
    };
  };

  # Ensure opencode's AGENTS.md always includes the jjwork rule
  # This is appended to the auto-generated file on activation
  home.activation.opencode-agents = lib.mkAfter ''
        AGENTS_FILE="$HOME/.config/opencode/AGENTS.md"
        if [ -f "$AGENTS_FILE" ] && [ -w "$AGENTS_FILE" ] && ! grep -q "jjwork" "$AGENTS_FILE"; then
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
