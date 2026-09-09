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

  # Typst authoring skills (local docs mirrors for typst + touying).
  # Upstream: https://github.com/apcamargo/typst-skills
  typstSkillsSrc = pkgs.fetchFromGitHub {
    owner = "apcamargo";
    repo = "typst-skills";
    rev = "93978422d58d4e5c21efe4bfa9f3e6dd9940cf96";
    hash = "sha256-Tmf8xoKNF0wxNvS+av3sOp6Pe0j2MwfeaxrUvlD9VFU=";
  };

  # Merge repo-local skills with the vendored typst skills; the skills
  # option maps attr names to skill directory names.
  sharedSkills =
    lib.mapAttrs (name: _: ../skills + "/${name}") (builtins.readDir ../skills)
    // {
      typst-author = "${typstSkillsSrc}/typst-author";
      touying-author = "${typstSkillsSrc}/touying-author";
    };

  # Fixed port of the long-lived shared server. Local TUIs attach to it via the
  # `oc` fish function instead of spawning throwaway servers, so TUI and web UI
  # share one session store.
  webPort = 4096;
in {
  programs.opencode = {
    enable = true;

    # PATH-prefixed with the rm shim so every bash tool call from the shared
    # server (TUI and web sessions alike) deletes to the rip2 graveyard.
    package = config.ai-assistants.safeRm.wrap (pkgs.symlinkJoin {
      name = "opencode-wrapped";
      paths = [pkgs.opencode];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
          --set NODE_TLS_REJECT_UNAUTHORIZED "0"
      '';
      meta.mainProgram = "opencode";
    });

    # Enable programs.mcp integration - HM module correctly transforms command+args+env
    enableMcpIntegration = true;

    extraPackages = with pkgs; [
      github-mcp-server
      mcp-nixos
      mcp-language-server
      # Typst toolchain (documents, slides, CVs)
      typst
      typstyle
      tinymist
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
      # Hide unused providers from the model list. Zen's gateway id is
      # "opencode" (distinct from the "opencode-go" subscription provider);
      # ollama-cloud is auto-detected from the OLLAMA_API_KEY environment,
      # hidden here as a guard alongside the removed export below.
      disabled_providers = ["opencode" "ollama-cloud"];
      agent = {
        explore.model = "github-copilot/gpt-5-mini";
        general.model = "github-copilot/gpt-5-mini";
        title.model = "github-copilot/gpt-5-mini";
        summary.model = "github-copilot/gpt-5-mini";
        compaction.model = "github-copilot/gpt-5-mini";
      };
      # tokenscope is server-side only (debugging tool, no TUI pane).
      # Quota stays in tui.plugin for the compact status line.
      plugin = ["@slkiser/opencode-quota" "@ramtinj95/opencode-tokenscope@latest" "@mohak34/opencode-notifier"];
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
        typstyle = {};
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

  # TokenScope slash command: invokes the plugin tool and prints the report verbatim.
  # Required by @ramtinj95/opencode-tokenscope; plugin alone does not register /tokenscope.
  xdg.configFile."opencode/command/tokenscope.md".text = ''
    ---
    description: Analyze token usage across the current session with detailed breakdowns by category
    ---

    Call the tokenscope tool directly without delegating to other agents.
    Leave sessionID unset unless the user explicitly asked to analyze a different session.
    Then read the exact unique report path returned by TokenScope.
    Return that file verbatim without additional text or formatting.
  '';

  # TokenScope feature flags. Stable user override read once at startup.
  xdg.configFile."opencode/tokenscope-config.json".text = builtins.toJSON {
    enableContextBreakdown = true;
    enableToolSchemaEstimation = true;
    enableCacheEfficiency = true;
    enableSubagentAnalysis = true;
    enableDetailedSubagentCostBreakdown = false;
    enableSkillAnalysis = true;
  };

  # Quota display policy: active OpenCode Go subscription provides remote
  # quota via the official usage API, so toasts/sidebar/reset notifications
  # are enabled and pinned to opencode-go. Compact status line stays on.
  xdg.configFile."opencode/opencode-quota/quota-toast.json".text = builtins.toJSON {
    enabledProviders = ["opencode-go"];
    formatStyle = "singleWindow";
    percentDisplayMode = "remaining";
    accountingDetail = "summary";
    tuiCommandDisplay = "inline";
    enableToast = true;
    resetNotifications = {
      enabled = true;
      windows = ["weekly"];
    };
    tuiSidebarPanel = {
      enabled = true;
    };
    tuiCompactStatus = {
      enabled = true;
      homeBottom = true;
      sessionPrompt = false;
    };
    tuiPromptBar = {
      enabled = false;
    };
    showSessionTokens = true;
    sessionTokenScope = "current";
  };

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

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
