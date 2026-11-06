{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) user defaults;

  herdrBoard = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr-board;

  # The board's project selection singletons on the daemon side: the first
  # board-aware command bootstraps a project from the cwd's git root when no
  # selection exists, and a colocated jj workspace root resolves to itself
  # (each working copy carries its own .git file), so a bare board command
  # from a workspace would fork a per-workspace project. BOARD_SCOPE_PATH in
  # every pane and interactive shell answers that bootstrap with the canonical
  # repo path instead; a resulting `board project select` (the summon key's
  # cwd or an explicit one-time call) pins the selection permanently.
  scopeEnv = "BOARD_SCOPE_PATH=${defaults.paths.nixosConfig}";

  # Same environment the herdr session server runs with: the daemon shells
  # out to `herdr` for session discovery and configured-harness placement.
  serviceEnvironment = [
    "SHELL=/etc/profiles/per-user/${user}/bin/fish"
    "PATH=/run/wrappers/bin:/home/${user}/.local/bin:/home/${user}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
    scopeEnv
  ];
in {
  options.tui.herdrBoard = {
    enable = lib.mkEnableOption "herdr-board kanban seat (packages, herdr summon key, ocws hygiene hook)" // {default = true;};
  };

  config = lib.mkIf config.tui.herdrBoard.enable {
    # `board` on PATH everywhere: card agents comment and report through it,
    # humans summon the TUI, and ocws's removal paths call it guard-silent.
    home.packages = [herdrBoard];

    home.sessionVariables.BOARD_SCOPE_PATH = defaults.paths.nixosConfig;

    # Summon the board from any herdr pane, same contributed-key pattern as
    # the ocws board, TTT editor and tuicr review keys (prefix+shift is
    # already taken by r/n/g/w/d/t/x/p in herdr's defaults; k stays free).
    # The popup runs board's TUI directly - herdr-board's plugin overlay is
    # deliberately not installed, because the manifest build is a cargo
    # compile inside herdr's managed checkout (network + toolchain at every
    # activation), while the packaged binary reaches the same TUI. board tui
    # auto-starts boardd detached, so closing the popup never takes a
    # mid-flight agent's daemon down.
    tui.herdr.commandKeys = lib.mkAfter [
      {
        key = "prefix+shift+k";
        type = "popup";
        command = "cd ${lib.escapeShellArg defaults.paths.nixosConfig} && board tui";
        description = "Open the herdr-board kanban (dispatch seat)";
        width = "95%";
        height = "95%";
      }
    ];

    # Card panes and any bare board CLI inside them resolve the repo project
    # even before a selection exists (see scopeEnv above).
    tui.herdr.paneEnvironment = [scopeEnv];

    # Always-on boardd on the agent-herd host only (tui.herdr.server stays
    # m920q's herdr server unit): run dispatches from the phone or a remote
    # attach without an interactive shell, and re-adopt runs after crashes
    # (on-failure restart; a clean stop is not). A stray auto-started
    # daemon from an early CLI call wins the DB flock and this unit then
    # exits silently with nothing serving from systemd's view - functional,
    # just worth remembering when `systemctl --user status herdr-boardd`.
    systemd.user.services.herdr-boardd = lib.mkIf config.tui.herdr.server.enable {
      Unit.Description = "herdr-board kanban daemon (boardd) dispatching agent runs";
      Service = {
        Type = "simple";
        ExecStart = "${herdrBoard}/bin/board daemon start --foreground";
        Restart = "on-failure";
        RestartSec = "3";
        Environment = serviceEnvironment;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
