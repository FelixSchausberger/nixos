{
  config,
  inputs,
  pkgs,
  ...
}: let
  defaults = import ../../../../lib/defaults.nix;
  yaziPackage = inputs.yazi.packages.${pkgs.hostPlatform.system}.default;
  noteLauncher = pkgs.writeShellApplication {
    name = "yazi-notes";
    runtimeInputs = [pkgs.coreutils yaziPackage];
    checkPhase = ''
      # Skip shellcheck - it doesn't recognize trap usage
      runHook preCheck
      runHook postCheck
    '';
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      if ! command -v nvim >/dev/null 2>&1; then
        printf 'yazi-notes: unable to find nvim in PATH\n' >&2
        exit 1
      fi

      tmp="$(mktemp -t yazi-note.XXXXXX)"
      cwd_tmp="$(mktemp -t yazi-note-cwd.XXXXXX)"

      cleanup() {
        rm -f "$tmp" "$cwd_tmp"
      }
      trap cleanup EXIT

      note_dir="''${NOTES_DIR:-${defaults.paths.obsidianVault}}"
      if [ "$#" -eq 0 ]; then
        set -- "$note_dir"
      fi

      ${yaziPackage}/bin/yazi "$@" --chooser-file="$tmp" --cwd-file="$cwd_tmp"
      status=$?

      if [ -s "$tmp" ]; then
        mapfile -t selection < "$tmp"
        if [ "''${#selection[@]}" -gt 0 ]; then
          nvim "''${selection[@]}"
        fi
      fi

      exit "$status"
    '';
  };
in {
  imports = [
    ./plugins
    ./theme/filetype.nix
    ./theme/icons.nix
    ./theme/manager.nix
    ./theme/status.nix
  ];

  home = {
    packages = [
      pkgs.exiftool # General file info
      pkgs.skim # Skim (sk) fuzzy finder for quick note selection
      noteLauncher
    ];

    shellAliases = {
      ym = "cd /per/mnt/2tb-ssd/media; yazi";
      yn = "yazi-notes";
    };
  };

  programs.bash = {
    enable = true;

    bashrcExtra = ''
      function y() {
      	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
      	yazi "$@" --cwd-file="$tmp"
      	if cwd="$(${pkgs.coreutils}/bin/cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      		builtin cd -- "$cwd"
      	fi
      	rm -f -- "$tmp"
      }
    '';
  };

  programs.yazi = {
    enable = true;

    package = yaziPackage;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;

    shellWrapperName = "y";

    settings = {
      mgr = {
        layout = [1 4 3];
        sort_by = "alphabetical";
        sort_sensitive = true;
        sort_reverse = false;
        sort_dir_first = true;
        linemode = "none";
        show_hidden = true;
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        cache_dir = config.xdg.cacheHome;
      };
    };
  };
}
