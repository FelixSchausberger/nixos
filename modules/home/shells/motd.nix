{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.programs.motd;
in {
  options.programs.motd = {
    enable = lib.mkEnableOption "Message of the Day (MOTD) using git-trending";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.trotd;
      description = "The git-trending package to use for MOTD";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to git-trending configuration file (trotd.toml). If null, uses default configuration.";
      example = "/per/repos/trotd/trotd.toml";
    };

    fishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to integrate MOTD with fish shell initialization";
    };

    bashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to integrate MOTD with bash shell initialization";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # Fish shell integration - display MOTD after shell initialization
    # This ensures it runs AFTER zellij/tmux/starship initialization
    programs.fish.interactiveShellInit = lib.mkIf cfg.fishIntegration (
      lib.mkAfter ''
        # MOTD integration - runs after shell fully initialized
        # Only in outermost interactive shell (not inside tmux/zellij)
        if status is-interactive; and not set -q TMUX; and not set -q ZELLIJ; and not set -q ZELLIJ_SESSION_NAME
          if not set -q __MOTD_DISPLAYED
            set -gx __MOTD_DISPLAYED 1
            # Use event handler to run after first prompt (ensures starship etc. are ready)
            function __git_trending_motd --on-event fish_prompt
              ${cfg.package}/bin/git-trending 2>/dev/null; or true
              functions -e __git_trending_motd  # Remove this function after first run
            end
          end
        end
      ''
    );

    # Bash shell integration - display MOTD after shell initialization
    programs.bash.initExtra = lib.mkIf cfg.bashIntegration (
      lib.mkAfter ''
        # MOTD integration - only in outermost interactive shell
        if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ -z "$ZELLIJ" ]; then
          if [ -z "$__MOTD_DISPLAYED" ]; then
            export __MOTD_DISPLAYED=1
            # Run git-trending (automatically uses config from ~/.config/trotd/trotd.toml if it exists)
            ${cfg.package}/bin/git-trending 2>/dev/null || true
          fi
        fi
      ''
    );

    # Optionally create symlink to config file
    home.file.".config/trotd/trotd.toml" = lib.mkIf (cfg.configFile != null) {
      source = cfg.configFile;
    };
  };
}
