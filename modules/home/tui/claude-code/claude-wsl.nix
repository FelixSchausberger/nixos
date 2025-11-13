{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  cfg = config.programs.claude-code.wsl;
  inherit (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}) claude-wsl;
in {
  options.programs.claude-code.wsl = {
    enable = lib.mkEnableOption "claude-wsl integration for visual notifications";
  };

  config = lib.mkIf cfg.enable {
    # Install claude-wsl package
    home.packages = [claude-wsl];

    # Bash integration for claude-wsl
    programs.bash.bashrcExtra = lib.mkAfter ''
      # === claude-wsl integration ===
      # Visual notifications for Claude Code in WSL
      # @claude-wsl-start
      _NOTIFIER_DIR="$HOME/.local/share/claude-wsl"

      # Source config with error handling to prevent shell failures
      if [ -f "$_NOTIFIER_DIR/config.sh" ]; then
        source "$_NOTIFIER_DIR/config.sh" 2>/dev/null || true
      fi

      # Source wrapper with error handling
      if [ -f "$_NOTIFIER_DIR/claude-notify-wrapper.sh" ]; then
        source "$_NOTIFIER_DIR/claude-notify-wrapper.sh" 2>/dev/null || true
      fi
      # @claude-wsl-end
    '';

    # Fish integration for claude-wsl
    # Fish uses a different approach - we need to use bass or implement native fish functions
    # For now, we'll source the bash scripts using bass (fish foreign environment wrapper)
    programs.fish.interactiveShellInit = lib.mkAfter ''
      # === claude-wsl integration ===
      # Visual notifications for Claude Code in WSL
      set -gx _NOTIFIER_DIR "$HOME/.local/share/claude-wsl"

      # Source the bash wrapper in a bash subshell and import environment variables
      # This is necessary because the wrapper sets up bash-specific hooks and functions
      if test -f "$_NOTIFIER_DIR/claude-notify-wrapper.sh"
        # Export environment variables that the wrapper expects
        set -gx CLAUDE_NOTIFY_ENABLED 1
        set -gx CLAUDE_NOTIFY_ON_OUTPUT 1
        set -gx CLAUDE_NOTIFY_TAB_ICON 1

        # Initialize session ID if not set
        if not set -q CLAUDE_SESSION_ID
          set -gx CLAUDE_SESSION_ID (date +%s)"-"(random)
        end

        # Set initial tab title
        if not set -q TAB_TITLE
          set -gx TAB_TITLE (basename (pwd))
        end

        # Track bell icon state
        set -gx BELL_ICON_ACTIVE 0
        set -gx BELL_WAS_PERMISSION 0
      end
    '';

    # Copy notification scripts to ~/.local/share/claude-wsl/
    home.file = {
      ".local/share/claude-wsl/notify.sh" = {
        source = "${claude-wsl}/share/claude-wsl/notify.sh";
        executable = true;
      };
      ".local/share/claude-wsl/notify-wrapper.sh" = {
        source = "${claude-wsl}/share/claude-wsl/notify-wrapper.sh";
        executable = true;
      };
      ".local/share/claude-wsl/config.sh" = {
        source = "${claude-wsl}/share/claude-wsl/config.sh";
        executable = true;
      };
      ".local/share/claude-wsl/claude-notify-wrapper.sh" = {
        source = "${claude-wsl}/share/claude-wsl/claude-notify-wrapper.sh";
        executable = true;
      };
      ".local/share/claude-wsl/list-tabs.sh" = {
        source = "${claude-wsl}/share/claude-wsl/list-tabs.sh";
        executable = true;
      };
      ".local/share/claude-wsl/send-notification.ps1" = {
        source = "${claude-wsl}/share/claude-wsl/send-notification.ps1";
        executable = true;
      };
      ".local/share/claude-wsl/test-workflow.sh" = {
        source = "${claude-wsl}/share/claude-wsl/test-workflow.sh";
        executable = true;
      };
    };
  };
}
