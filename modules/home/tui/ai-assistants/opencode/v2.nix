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
  # mcp.servers form (command array + environment).
  v2McpServers =
    lib.mapAttrs (_name: server: {
      type = "local";
      command = [server.command] ++ (server.args or []);
      environment = server.env or {};
    })
    config.programs.mcp.servers;

  # V2 takes skill directories as path entries. Assemble the repo + typst skills
  # into one directory so a single entry covers them all.
  combinedSkills = pkgs.runCommand "opencode-v2-skills" {} (
    lib.concatStringsSep "\n" (
      ["mkdir -p $out"]
      ++ lib.mapAttrsToList (name: path: "ln -s ${path} $out/${name}") shared.sharedSkills
    )
  );

  v2Config = {
    inherit (shared) model;
    permissions = shared.permissionRules;
    formatter = shared.formatters;
    skills = [combinedSkills];
    mcp.servers = v2McpServers;
    # No server-side plugins yet: the V1 plugin set does not run under V2. The
    # Zellij indicator is a CLI plugin and lives in cli.json instead.
    plugins = [];
  };

  # The V2 terminal client owns a global cli.json. The patched indicator fork is
  # referenced by absolute path and deliberately sits outside the
  # auto-discovered plugins/ directory so the server role never loads it. The
  # theme/session/diff settings mirror the stray V2 cli.json that an
  # unisolated opencode2 run wrote into the V1 config directory; V1 itself
  # never reads cli.json, so they exist only for the V2 TUI.
  indicatorV2Dir = "${config.xdg.configHome}/${v2ConfigDir}/indicator-v2";
  cliConfig = {
    theme.name = "stylix";
    plugins = [indicatorV2Dir];
    diffs.wrap = "word";
    session = {
      sidebar = "auto";
      scrollbar = false;
      thinking = "show";
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
  # spawned from opencode2 sessions.
  opencode2 = pkgs.writeShellScriptBin "opencode2" ''
    exec env OPENCODE_CONFIG_DIR="${config.xdg.configHome}/${v2ConfigDir}" ${inputs.opencode-v2.packages.${system}.opencode}/bin/opencode2 "$@"
  '';
in {
  options.ai-assistants.opencodeV2 = {
    enable = lib.mkEnableOption "OpenCode 2 beta (opencode2) with a config rendered from the shared source";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [opencode2];

    xdg.configFile = {
      "${v2ConfigDir}/opencode.jsonc".text = builtins.toJSON v2Config;
      "${v2ConfigDir}/cli.json".text = builtins.toJSON cliConfig;
      "${v2ConfigDir}/AGENTS.md".text = shared.combinedRules;
      "${v2ConfigDir}/agents/code-simplifier.md".text = shared.codeSimplifierAgent;
      "${v2ConfigDir}/indicator-v2".source = ./zellij-indicator-v2;
    };
  };
}
