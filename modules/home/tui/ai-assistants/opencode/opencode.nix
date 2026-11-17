{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  # Single source for the harness: model, agent rules, permissions, formatters,
  # skills and quota policy. shared.nix is V2-native, so there is no second
  # renderer to keep in sync.
  shared = import ./shared.nix {inherit config lib pkgs;};

  # The canonical config root.
  configDir = "opencode";

  # v6 has no enabled-providers allowlist: a provider with a detected login is
  # on unless `providers.off` names it. This is @slkiser/opencode-quota
  # 6.2.2's catalog minus the Go subscription, so Zen and every other detected
  # login stay off; a provider added upstream defaults on until it is listed
  # here.
  quotaOffProviders = [
    "anthropic"
    "copilot"
    "openai"
    "openrouter"
    "cursor"
    "alibaba-coding-plan"
    "alibaba-token-plan"
    "google-gemini-cli"
    "google-agy"
    "zai"
    "zhipu"
    "minimax-coding-plan"
    "minimax-china-coding-plan"
    "kimi-code-plan-global"
    "kimi-code-plan-cn"
    "deepseek"
    "xai"
    "xiaomi"
    "opencode"
    "ollama-cloud"
    "custom"
  ];

  # programs.mcp.servers reshaped into V2's mcp.servers form (command array +
  # environment). File-backed env values become the {file:path} token V2
  # substitutes at config load.
  mcpEnv = lib.mapAttrs (
    _: value:
      if lib.isAttrs value && value ? file
      then "{file:${value.file}}"
      else value
  );

  mcpServers =
    lib.mapAttrs (_name: server: {
      type = "local";
      command = [server.command] ++ (server.args or []);
      environment = mcpEnv (server.env or {});
    })
    config.programs.mcp.servers;

  # V2 takes skill directories as path entries. Assemble the repo + typst skills
  # into one directory so a single entry covers them all.
  combinedSkills = pkgs.runCommand "opencode-skills" {} (
    lib.concatStringsSep "\n" (
      ["mkdir -p $out"]
      ++ lib.mapAttrsToList (name: path: "ln -s ${path} $out/${name}") shared.sharedSkills
    )
  );

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    inherit (shared) model;
    permissions = shared.permissionRules;
    formatter = shared.formatters;
    # Agent tool calls and the terminal run this shell, so they inherit the rm
    # shim (see agentShell above).
    shell = "${agentShell}/bin/bash";
    skills = [combinedSkills];
    mcp.servers = mcpServers;
    # Server-side package plugins. @slkiser/opencode-quota 6 peers
    # @opencode/plugin 2.0.28+ and renders its sidebar and status line through
    # the V2 API; the major is pinned so a future major cannot move the
    # settings schema under the declarative settings file.
    # opencode-tokenscope-v2 is the V2 port of TokenScope - the upstream
    # @ramtinj95 package is V1-only - and registers both the `tokenscope` tool
    # and the /tokenscope command itself, so no command file is deployed for
    # it. The Zellij indicator is a CLI plugin and lives in cli.json instead.
    plugins = [
      "@slkiser/opencode-quota@6"
      "@cheesecodestudio/opencode-tokenscope-v2"
    ];
  };

  # The terminal client owns a global cli.json, which only the client role
  # reads. Client-side plugins are referenced by absolute path and deliberately
  # sit outside the auto-discovered plugins/ directory so the server role never
  # loads them: the indicator paints the pane title, the seat claim renames the
  # workspace its own TUI runs in.
  indicatorDir = "${config.xdg.configHome}/${configDir}/indicator-v2";
  seatDir = "${config.xdg.configHome}/${configDir}/ocws-seat";
  cliConfig = {
    "$schema" = "https://opencode.ai/v2/cli.json";
    theme.name = "stylix";
    # CLI-only plugins, loaded by the terminal client and never by the server
    # role. Only the Zellij indicator remains here: the status-line plugin was
    # removed because its 1s heartbeat re-render exhausts the opentui
    # TextBuffer handle pool and freezes the TUI. An A/B test with two
    # concurrent `-c` sessions (full config vs. quota surfaces off vs. no
    # status-line) crashed both status-line arms with "Failed to create
    # TextBuffer" ~4:14 after start while the arm without the plugin survived
    # the whole window, matching 19 historical crashes that all began with the
    # plugin's introduction in 1b6dda9. The render leak itself is upstream
    # (opentui #1493); until it is fixed the plugin must not come back.
    plugins =
      [
        indicatorDir
        seatDir
      ]
      # herdr's opencode lifecycle integration, vendored by the herdr module
      # (option tui.herdr.opencodeIntegration). Upstream registers the V2
      # integration as this directory path in cli.json; here it resolves
      # against the rendered config root. Never ship the auto-discovered
      # server-side herdr plugin alongside it: pane-local TUI reporting must
      # remain the only state reporter (herdr integration docs).
      ++ lib.optionals
      (
        config.tui.herdr.opencodeIntegration.enable or false
      )
      ["./herdr-opencode"];
    diffs.wrap = "word";
    # The footer already carries context tokens and percentage, the quota bar,
    # the model and the cwd, and the pane title names the session; the sidebar's
    # remaining block is the MCP list, which `/mcps` still opens. Hiding it
    # returns a full column to the transcript.
    session = {
      sidebar = "hide";
      scrollbar = false;
      thinking = "show";
    };
    # Native attention: system notifications plus sound for
    # permission/question/error/done events. Per-event enablement is not
    # configurable; notifications fire only when the terminal is unfocused,
    # while sounds play regardless of focus.
    attention = {
      notifications = true;
      sound = true;
    };
    animations = true;
  };

  # The upstream flake ships one launcher that resolves its `.opencode-wrapped`
  # payload from its own store directory, so it must be exec'd by absolute path.
  # Both process families - the TUI and the shared systemd server - run through
  # this script.
  #
  # GITHUB_TOKEN is unset defensively: opencode synthesizes a github-copilot
  # provider from that variable, which the Copilot API rejects for the fleet's
  # PAT; the company tool is reserved for IntelliJ/CLI. The login shell exports
  # the PAT as GH_UPDATE_TOKEN instead, and gh authenticates through hosts.yml,
  # so nothing in this tree needs GITHUB_TOKEN - the unset still covers values
  # inherited from ssh sessions, CI or a manual export.
  #
  # PATH carries the rip-backed rm shim and RIP_GRAVEYARD pins the graveyard
  # (modules/home/tui/ai-assistants/safe-rm.nix). It reaches this process and
  # anything it spawns directly, but NOT agent tool calls: opencode builds the
  # tool shell's PATH from the login shell environment, so a prefix here is
  # invisible to them. agentShell below is what covers the tools.
  # Upstream regenerates nix/hashes.json from its dev branch, and the v2.3.0
  # tag still carries the 2026-10-31 value, which predates the release's
  # dependency changes, so the fixed-output node_modules derivation rejects the
  # tree bun produces from the tag's own lockfile. Pin the hash the build
  # reports for this source with the flake's rev-pinned nixpkgs; both sides are
  # pinned, so the value cannot drift.
  opencodeUpstream = inputs.opencode-v2.packages.${system}.opencode;
  opencodePackage = opencodeUpstream.override {
    node_modules = opencodeUpstream.node_modules.override (
      lib.optionalAttrs (system == "x86_64-linux") {
        hash = "sha256-PYcpyYP/i0e6ZIt27u1tFYbjU4Cl848w77dU1NiIEls=";
      }
    );
  };

  # The shell opencode uses for agent tool calls. It must be one that resolves
  # `rm` to the graveyard shim, which the fleet's shell functions cannot do:
  # modules/home/shells defines `rm` as an interactive-only convenience that
  # falls back to the real rm whenever it is not interactive, precisely so it
  # never breaks automation. The shim therefore has to be on PATH instead, and
  # only a shell we own can put it there for tool calls alone.
  #
  # Named `bash`: opencode inspects the shell name to choose its command
  # dialect, and discovering the fleet's login shell already selects bash.
  agentShell = pkgs.writeTextFile {
    name = "opencode-agent-shell";
    executable = true;
    destination = "/bin/bash";
    text = ''
      #!${pkgs.bash}/bin/bash
      exec env PATH="${config.ai-assistants.safeRm.package}/bin:$PATH" ${pkgs.bash}/bin/bash "$@"
    '';
  };

  launcher = pkgs.writeShellScript "opencode-launcher" ''
    exec env -u GITHUB_TOKEN \
      RIP_GRAVEYARD="${config.ai-assistants.safeRm.graveyard.path}" \
      PATH="${config.ai-assistants.safeRm.package}/bin:$PATH" \
      ${opencodePackage}/bin/opencode2 "$@"
  '';

  # Both entry points resolve to the same launcher. Upstream builds `opencode`
  # and symlinks `opencode2` at it; the distinction is kept only because `oc`
  # and muscle memory use `opencode2` while the nixvim integration and other
  # tools invoke `opencode`.
  opencode = pkgs.runCommand "opencode" {} ''
    mkdir -p $out/bin
    ln -s ${launcher} $out/bin/opencode
    ln -s ${launcher} $out/bin/opencode2
  '';
in {
  options.ai-assistants.opencode = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Launcher package exposing opencode and opencode2 with the fleet config root, graveyard path and rm shim applied";
    };
  };

  config = {
    ai-assistants.opencode.package = opencode;

    home.packages = [opencode];

    # The shared server every client attaches to. `serve --service` registers
    # itself as the user's background service, so the TUI, `oc` and the nixvim
    # integration discover this exact URL and password instead of auto-starting
    # a second server on a random port. Only the loopback bind and the fixed
    # port are pinned here, for the Tailscale Serve target in
    # modules/system/homelab/opencode-web.nix. PATH must stay resolvable under
    # systemd because the server hands its environment to every bash tool it
    # runs; the launcher prefixes the rm shim onto it.
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "OpenCode shared server (API and web UI)";
        After = ["network.target"];
      };
      Service = {
        # A single command string, never a multi-element argv list: Home
        # Manager renders one systemd ExecStart= line per list element, and
        # systemd rejects a Type=simple unit with more than one ("more than
        # one ExecStart= setting"). The option coerces the string into a
        # one-element list, which is exactly what the unit needs.
        ExecStart = "${opencode}/bin/opencode2 serve --service --hostname 127.0.0.1 --port ${toString shared.webPort}";
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        ];
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };

    xdg.configFile = {
      "${configDir}/opencode.jsonc".text = builtins.toJSON opencodeConfig;
      "${configDir}/cli.json".text = builtins.toJSON cliConfig;
      "${configDir}/AGENTS.md".text = shared.combinedRules;
      "${configDir}/agents/code-simplifier.md".text = shared.codeSimplifierAgent;
      # TokenScope reads this from the canonical $XDG_CONFIG_HOME/opencode
      # rather than the plugin host, so declaring it here keeps the fleet's
      # flags explicit instead of inheriting the plugin's defaults. The schema
      # is partial: unlisted keys fall back to the plugin's own defaults.
      "${configDir}/tokenscope-config.json".text = builtins.toJSON {
        enableContextBreakdown = true;
        enableToolSchemaEstimation = true;
        enableCacheEfficiency = true;
        enableSubagentAnalysis = true;
        enableDetailedSubagentCostBreakdown = false;
        enableSkillAnalysis = true;
      };
      # Quota policy from shared.nix, scoped to the Go subscription. The Zen
      # gateway (provider id `opencode`, synonym `opencode-zen`) is listed off
      # deliberately: only free models are used there, and neither the quota
      # plugin nor the Console billing API exposes a free-tier usage
      # percentage - only balance, spend and a budget percent that needs a
      # USD monthly limit. A balance row is useless when nothing is planned to
      # be spent, so Zen stays off. The list is merged rather than reassigning
      # `providers` so other provider settings from shared.nix survive.
      "${configDir}/opencode-quota/settings.jsonc".text = builtins.toJSON (
        lib.recursiveUpdate shared.quotaSettings {
          providers.off = quotaOffProviders;
        }
      );
      "${configDir}/indicator-v2".source = ./zellij-indicator-v2;
      "${configDir}/ocws-seat".source = ./ocws-seat;
    };
  };
}
