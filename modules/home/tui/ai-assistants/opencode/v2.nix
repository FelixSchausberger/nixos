{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.ai-assistants.opencode;
  system = pkgs.stdenv.hostPlatform.system;

  # Single source for the harness: model, agent rules, permissions, formatters,
  # skills and quota policy. shared.nix is V2-native, so there is no second
  # renderer to keep in sync.
  shared = import ./shared.nix {inherit config lib pkgs;};

  # The config root is kept out of the canonical ~/.config/opencode on purpose:
  # that directory still holds imperative leftovers from the retired V1 tree
  # (node_modules, bun.lock, tui.json, stray service-prod.json) which this
  # module no longer manages and must not resurrect. Moving the V2 tree into
  # the canonical location is a separate change.
  v2ConfigDir = "opencode-v2/opencode";

  # programs.mcp.servers reshaped into V2's mcp.servers form (command array +
  # environment). File-backed env values become the {file:path} token V2
  # substitutes at config load.
  v2McpEnv = lib.mapAttrs (
    _: value:
      if lib.isAttrs value && value ? file
      then "{file:${value.file}}"
      else value
  );

  v2McpServers =
    lib.mapAttrs (_name: server: {
      type = "local";
      command = [server.command] ++ (server.args or []);
      environment = v2McpEnv (server.env or {});
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

  v2Config = {
    "$schema" = "https://opencode.ai/config.json";
    inherit (shared) model;
    permissions = shared.permissionRules;
    formatter = shared.formatters;
    # Agent tool calls and the terminal run this shell, so they inherit the rm
    # shim (see agentShell above).
    shell = "${agentShell}/bin/bash";
    skills = [combinedSkills];
    mcp.servers = v2McpServers;
    # Server-side package plugins. @slkiser/opencode-quota 5 peers
    # @opencode/plugin 2.x and renders its sidebar/toast surfaces through the
    # V2 API; the major is pinned because npm `latest` tracks a release that
    # dropped V2's predecessor. opencode-tokenscope-v2 is the V2 port of
    # TokenScope - the upstream @ramtinj95 package is V1-only - and registers
    # both the `tokenscope` tool and the /tokenscope command itself, so no
    # command file is deployed for it. The Zellij indicator is a CLI plugin and
    # lives in cli.json instead. ntfy-mobile is added only where mobilePush is
    # enabled; it is referenced by absolute path and kept outside the
    # auto-discovered plugins/ directory so only the server role, which owns
    # the event stream, loads it.
    plugins =
      [
        "@slkiser/opencode-quota@5"
        "@cheesecodestudio/opencode-tokenscope-v2"
      ]
      ++ lib.optional cfg.mobilePush.enable {
        package = "${config.xdg.configHome}/${v2ConfigDir}/ntfy-mobile";
        options =
          {
            url = cfg.mobilePush.ntfyUrl;
            topic = cfg.mobilePush.topic;
          }
          // lib.optionalAttrs (cfg.mobilePush.clickBase != "") {
            clickBase = cfg.mobilePush.clickBase;
          }
          // lib.optionalAttrs (cfg.mobilePush.tokenFile != null) {
            tokenFile = toString cfg.mobilePush.tokenFile;
          };
      };
  };

  # The terminal client owns a global cli.json, which only the client role
  # reads. The patched indicator fork is referenced by absolute path and
  # deliberately sits outside the auto-discovered plugins/ directory so the
  # server role never loads it.
  indicatorV2Dir = "${config.xdg.configHome}/${v2ConfigDir}/indicator-v2";
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
    plugins = [
      indicatorV2Dir
    ];
    diffs.wrap = "word";
    session = {
      sidebar = "auto";
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
  # this script, so everything set here reaches every bash tool call the server
  # executes.
  #
  # OPENCODE_CONFIG_DIR pins the config root. Upstream falls back to
  # $XDG_CONFIG_HOME/opencode, which is the retired V1 directory; XDG_CONFIG_HOME
  # itself is deliberately not used because it would leak into every child
  # process (bash tool calls, LSPs).
  #
  # GITHUB_TOKEN is unset because the login shell exports a GitHub PAT, from
  # which opencode synthesizes a github-copilot provider that the Copilot API
  # rejects; the company tool is reserved for IntelliJ/CLI. gh authenticates
  # through hosts.yml, so nothing in this tree needs the variable.
  #
  # PATH carries the rip-backed rm shim and RIP_GRAVEYARD pins the graveyard
  # (modules/home/tui/ai-assistants/safe-rm.nix). It reaches this process and
  # anything it spawns directly, but NOT agent tool calls: opencode builds the
  # tool shell's PATH from the login shell environment, so a prefix here is
  # invisible to them. agentShell below is what covers the tools.
  opencodePackage = inputs.opencode-v2.packages.${system}.opencode;

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
      OPENCODE_CONFIG_DIR="${config.xdg.configHome}/${v2ConfigDir}" \
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

    # Server-side push for the phone-facing server. Enabled only on the host
    # whose server the phone can reach (see the Tailscale Serve target in
    # modules/system/homelab/opencode-web.nix); the per-host loopback servers
    # the desktop, WSL and nvim clients attach to stay silent.
    mobilePush = {
      enable = lib.mkEnableOption "ntfy push notifications for the phone-facing OpenCode server";
      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:2586";
        description = "Base URL of the self-hosted ntfy instance, reachable from the server host (loopback)";
      };
      topic = lib.mkOption {
        type = lib.types.str;
        default = "opencode";
        description = "ntfy topic the phone subscribes to";
      };
      clickBase = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "URL a tapped notification opens; the web UI origin (its Tailscale Serve address)";
      };
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional file holding an ntfy access token, sent as a bearer credential";
      };
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

    # Belt and braces for launches that bypass the launcher (`nix shell`, an
    # absolute store path, any tool that inherits a bare PATH): without the
    # variable they read the retired ~/.config/opencode instead of this tree.
    home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.xdg.configHome}/${v2ConfigDir}";

    xdg.configFile = {
      "${v2ConfigDir}/opencode.jsonc".text = builtins.toJSON v2Config;
      "${v2ConfigDir}/cli.json".text = builtins.toJSON cliConfig;
      "${v2ConfigDir}/AGENTS.md".text = shared.combinedRules;
      "${v2ConfigDir}/agents/code-simplifier.md".text = shared.codeSimplifierAgent;
      # Quota policy from shared.nix, scoped to the Go subscription. The Zen
      # gateway (provider id `opencode`, synonym `opencode-zen`) is excluded
      # deliberately: only free models bill against it, and neither the quota
      # plugin nor the Console billing API exposes a free-tier usage
      # percentage - only balance, spend and a budget percent that needs a
      # USD monthly limit. A balance row is useless when nothing is planned
      # to be spent, so no Zen rows are rendered.
      "${v2ConfigDir}/opencode-quota/quota-toast.json".text = builtins.toJSON (
        shared.quotaToast
        // {enabledProviders = ["opencode-go"];}
      );
      "${v2ConfigDir}/indicator-v2".source = ./zellij-indicator-v2;
      # Server-side push plugin; listed above only when mobilePush is enabled.
      "${v2ConfigDir}/ntfy-mobile".source = ./ntfy-mobile;
    };
  };
}
