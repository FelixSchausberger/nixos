{
  pkgs,
  config,
  lib,
  ...
}: let
  # Shared config source rendered into both the V1 and V2 harnesses.
  shared = import ./shared.nix {inherit config lib pkgs;};
  inherit (shared) model;

  # V1 groups permission effects per tool; derive the bash map from the
  # canonical ordered rule list so the two harnesses cannot drift.
  v1BashPermissions = lib.listToAttrs (
    map (rule: lib.nameValuePair rule.resource rule.effect) (
      builtins.filter (rule: rule.action == "shell") shared.permissionRules
    )
  );

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
        # Pin the legacy database unconditionally. A stray OpenCode 2 run wrote
        # the v2 schema into the canonical opencode.db, defeating the nixpkgs
        # wrapper's only-if-absent workaround; setting OPENCODE_DB here keeps v1
        # on the file holding all sessions regardless of what else writes into
        # the shared ~/.local/share/opencode directory.
        #
        # --unset OPENCODE_CONFIG_DIR: a leaked export pointing at the V2
        # config dir makes V1 refuse to start ("V2 permissions are not
        # supported by OpenCode V1"). The V2 wrapper scopes that variable to
        # its own process tree; V1 always reads its own config dir.
        #
        # --unset GITHUB_TOKEN: a shell-exported GitHub PAT would shadow the
        # device-flow credential in auth.json, and the Copilot API rejects
        # PATs outright ("Personal Access Tokens are not supported for this
        # endpoint"). The MCP github server reads its token from the sops
        # file itself and needs nothing from the environment.
        #
        # NODE_EXTRA_CA_CERTS points Bun at the system bundle; TLS verification
        # stays on. An earlier NODE_TLS_REJECT_UNAUTHORIZED=0 here was a
        # workaround for TLS interception by an ESET SSL filter whose custom CA
        # has since been retired from this fleet.
        wrapProgram $out/bin/opencode \
          --set OPENCODE_DB "opencode-stable.db" \
          --unset OPENCODE_CONFIG_DIR \
          --unset GITHUB_TOKEN \
          --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
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

    context = shared.combinedRules;

    skills = shared.sharedSkills;

    settings = {
      inherit model;
      small_model = model;
      # Hide unused providers from the model list. ollama-cloud is
      # auto-detected from the OLLAMA_API_KEY environment, hidden here as a
      # guard alongside the removed export below. Zen's gateway id is
      # "opencode" (distinct from the "opencode-go" subscription provider)
      # and stays listed so its *-free models remain selectable.
      disabled_providers = ["ollama-cloud"];
      agent = {
        explore.model = model;
        general.model = model;
        title.model = model;
        summary.model = model;
        compaction.model = model;
      };
      # tokenscope is server-side only (debugging tool, no TUI pane).
      # Quota stays in tui.plugin for the compact status line.
      # zellij-indicator-felix: vendored fork of opencode-zellij-indicator
      # @0.7.0 (last V1-API release; 2.0.0 targets opencode 2) with session
      # titles truncated at ingestion - zjstatus has no per-name truncation
      # and full auto-generated titles overflow the tab bar. Relative path
      # resolves from ~/.config/opencode/opencode.json.
      plugin = [
        "@slkiser/opencode-quota"
        "@ramtinj95/opencode-tokenscope@latest"
        "./plugins/zellij-indicator-felix"
        "@mohak34/opencode-notifier"
      ];
      permission.bash = v1BashPermissions;
      formatter = shared.formatters;
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

  # Vendored fork of opencode-zellij-indicator@0.7.0 with title truncation
  # (provenance in its package.json). Deployed as a plugin package directory;
  # referenced above via a relative path from the global opencode.json.
  xdg.configFile."opencode/plugins/zellij-indicator-felix".source =
    ./zellij-indicator-felix;

  xdg.configFile."opencode/agents/code-simplifier.md".text = shared.codeSimplifierAgent;

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
