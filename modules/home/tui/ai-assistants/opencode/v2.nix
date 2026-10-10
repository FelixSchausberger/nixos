{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.ai-assistants.opencodeV2;
  system = pkgs.stdenv.hostPlatform.system;

  # Render the V2 config from the same source as V1, so the two harnesses cannot
  # drift (see shared.nix). The isolated config directory + the shim's
  # OPENCODE_CONFIG_DIR exist because V2 otherwise loads the V1 `plugin` list
  # by union, and the V1-only plugins (the vendored indicator especially) have
  # no V2 entrypoint: their load failure aborts plugin generation and blocks
  # agent registration, leaving `build` missing.
  shared = import ./shared.nix {inherit config lib pkgs;};

  v2ConfigDir = "opencode-v2/opencode";

  # Reuse the single programs.mcp.servers source, reshaped into V2's
  # mcp.servers form (command array + environment). File-backed env values
  # become the {file:path} token V2 substitutes at config load, mirroring the
  # V1 integration's renderEnv behavior.
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
  # The github server is excluded from programs.mcp.servers (V1.18.30
  # crashes mapping its tool list) but V2 handles it fine, so it is re-added
  # here with the file reference V2 substitutes at config load.
  v2McpServersGithub = {
    type = "local";
    command = ["${pkgs.github-mcp-server}/bin/github-mcp-server" "stdio"];
    environment.GITHUB_PERSONAL_ACCESS_TOKEN = "{file:${config.sops.secrets."github/token".path}}";
  };

  # V2 takes skill directories as path entries. Assemble the repo + typst skills
  # into one directory so a single entry covers them all.
  combinedSkills = pkgs.runCommand "opencode-v2-skills" {} (
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
    skills = [combinedSkills];
    mcp.servers = v2McpServers // {github = v2McpServersGithub;};
    # Server-side plugins the isolated V2 config loads. The V1 plugin list
    # does not run under V2 (no V2 entrypoint, see above), so only the V2
    # build of the quota plugin is listed: @slkiser/opencode-quota 5 peers
    # @opencode/plugin 2.0.16 and renders its sidebar/toast surfaces through
    # the V2 API. Pinned to the major because npm `latest` already moved to
    # a release that dropped OpenCode 1, and the same jump could strand V2.
    # The Zellij indicator is a CLI plugin and lives in cli.json instead.
    # ntfy-mobile is added only where mobilePush is enabled; it is referenced
    # by absolute path and kept outside the auto-discovered plugins/ directory
    # so only the server role, which owns the event stream, loads it.
    plugins =
      ["@slkiser/opencode-quota@5"]
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

  # The V2 terminal client owns a global cli.json. The patched indicator fork
  # is referenced by absolute path and deliberately sits outside the
  # auto-discovered plugins/ directory so the server role never loads it.
  # The theme/session/diff settings mirror the stray V2 cli.json that an
  # unisolated opencode2 run wrote into the V1 config directory; V1 itself
  # never reads cli.json, so they exist only for the V2 TUI.
  indicatorV2Dir = "${config.xdg.configHome}/${v2ConfigDir}/indicator-v2";
  cliConfig = {
    "$schema" = "https://opencode.ai/v2/cli.json";
    theme.name = "stylix";
    # CLI-only plugins, loaded by the terminal client and never by the
    # server role. Only the Zellij indicator remains here: the status-line
    # plugin was removed because its 1s heartbeat re-render exhausts the
    # opentui TextBuffer handle pool and freezes the TUI. An A/B test with
    # two concurrent `-c` sessions (full config vs. quota surfaces off vs.
    # no status-line) crashed both status-line arms with
    # "Failed to create TextBuffer" ~4:14 after start while the arm without
    # the plugin survived the whole window, matching 19 historical crashes
    # that all began with the plugin's introduction in 1b6dda9. The render
    # leak itself is upstream (opentui #1493); until it is fixed the plugin
    # must not come back.
    plugins = [
      indicatorV2Dir
    ];
    diffs.wrap = "word";
    session = {
      sidebar = "auto";
      scrollbar = false;
      thinking = "show";
    };
    # Native attention is V2's notification path: system notifications
    # plus sound for permission/question/error/done events. Per-event
    # enablement is not configurable; notifications fire only when the
    # terminal is unfocused, while sounds play regardless of focus.
    attention = {
      notifications = true;
      sound = true;
    };
    animations = true;
  };

  # The upstream V2 flake installs both bin/opencode and bin/opencode2 plus a
  # share/zsh/site-functions/_opencode completion. Adding the package directly
  # to home.packages collides with V1's `opencode` in home-manager-path
  # (buildEnv rejects the duplicate subpaths). Expose only an `opencode2`
  # entry point through a thin exec shim; the C launcher resolves its
  # `.opencode-wrapped` payload from its own store directory, so exec by
  # absolute path is required.
  #
  # OPENCODE_CONFIG_DIR is the only config-root override upstream V2 honors
  # (packages/util/src/global.ts falls back to $XDG_CONFIG_HOME/opencode).
  # Without it opencode2 reads the V1 ~/.config/opencode, whose `plugin` list
  # is V1-only: those plugins ship no ./server entrypoint, their load failure
  # aborts plugin generation and blocks agent registration, leaving the TUI
  # without modes or a working model picker. XDG_CONFIG_HOME is deliberately
  # not used: it would leak into every child process (bash tool calls, LSPs)
  # spawned from opencode2 sessions. Launch opencode2 only through this PATH
  # shim: `nix shell`, an absolute store path, or anything else that skips it
  # starts opencode2 without the variable and silently falls back to the V1
  # config above.
  #
  # GITHUB_TOKEN is unset for the reason documented on the V1 wrapper
  # (default.nix): the login shell exports a GitHub PAT and opencode
  # synthesizes a github-copilot provider from it that the Copilot API
  # rejects; the company tool is reserved for IntelliJ/CLI. MCP github reads
  # its token from the sops file and gh authenticates through hosts.yml, so
  # no part of the V2 tree needs the variable.
  # Upstream builds `bin/opencode` and symlinks `bin/opencode2` at it; the exec
  # shim below is the only entry point this module exposes.
  opencode2Package = inputs.opencode-v2.packages.${system}.opencode;

  opencode2 = pkgs.writeShellScriptBin "opencode2" ''
    exec env -u GITHUB_TOKEN OPENCODE_CONFIG_DIR="${config.xdg.configHome}/${v2ConfigDir}" ${opencode2Package}/bin/opencode2 "$@"
  '';
in {
  options.ai-assistants.opencodeV2 = {
    enable = lib.mkEnableOption "OpenCode 2 beta (opencode2) with a config rendered from the shared source";

    # Server-side push for the phone-facing server. Enabled only on the host
    # whose server the phone can reach (see the Tailscale Serve target in
    # modules/system/homelab/opencode-web.nix); the per-host loopback servers
    # the desktop, WSL and nvim clients attach to stay silent.
    mobilePush = {
      enable = lib.mkEnableOption "ntfy push notifications for the phone-facing OpenCode 2 server";
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

  config = lib.mkIf cfg.enable {
    home.packages = [opencode2];

    # The shared server every V2 client attaches to; default.nix disables V1's
    # programs.opencode.web for this host so the two never race for the port.
    # `serve --service` registers itself as the user's background service, so
    # the TUI, `oc` and the nixvim integration discover this exact URL and
    # password instead of auto-starting a second server on a random port. Only
    # the loopback bind and the fixed port are pinned here, for the Tailscale
    # Serve target in modules/system/homelab/opencode-web.nix. PATH mirrors the
    # V1 launcher: the server hands its environment to every bash tool it runs,
    # so the user profile must stay resolvable under systemd.
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "OpenCode 2 shared server (API and web UI)";
        After = ["network.target"];
      };
      Service = {
        # A single command string, never a multi-element argv list: Home
        # Manager renders one systemd ExecStart= line per list element, and
        # systemd rejects a Type=simple unit with more than one ("more than
        # one ExecStart= setting"). The option coerces the string into a
        # one-element list, which is exactly what the unit needs.
        ExecStart = "${opencode2}/bin/opencode2 serve --service --hostname 127.0.0.1 --port ${toString shared.webPort}";
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        ];
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };

    # Belt and braces for launches that bypass the exec shim above (`nix
    # shell`, an absolute store path, any tool that inherits a bare PATH):
    # without the variable opencode2 silently unions the V1 config, whose
    # V1-only plugin list aborts V2 plugin generation. Exporting it for the
    # whole session is safe because the V1 wrapper unsets it for its own
    # process tree (default.nix) and V1 itself never reads it.
    home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.xdg.configHome}/${v2ConfigDir}";

    xdg.configFile = {
      "${v2ConfigDir}/opencode.jsonc".text = builtins.toJSON v2Config;
      "${v2ConfigDir}/cli.json".text = builtins.toJSON cliConfig;
      "${v2ConfigDir}/AGENTS.md".text = shared.combinedRules;
      "${v2ConfigDir}/agents/code-simplifier.md".text = shared.codeSimplifierAgentV2;
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
