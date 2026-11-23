{
  config,
  pkgs,
  ...
}: let
  noteLauncher = pkgs.writeShellApplication {
    name = "yazi-notes";
    runtimeInputs = [pkgs.coreutils pkgs.yazi];
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

      note_dir="''${NOTES_DIR:-${config.modules.home.tui.vault.path}}"
      if [ "$#" -eq 0 ]; then
        set -- "$note_dir"
      fi

      ${pkgs.yazi}/bin/yazi "$@" --chooser-file="$tmp" --cwd-file="$cwd_tmp"
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
    ./vfs.nix
  ];

  home = {
    packages = [
      pkgs.exiftool # General file info
      noteLauncher
    ];

    shellAliases = {
      ym = "cd /per/mnt/2tb-ssd/media; yazi";
      yn = "yazi-notes";
    };
  };

  programs.yazi = {
    enable = true;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;

    shellWrapperName = "y";

    settings = {
      mgr = {
        ratio = [1 4 3];
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
        # Windows terminals cannot report their pixel size over SSH, so Yazi
        # uses only these caps; 600 px was upscaled into a visibly soft
        # preview. 1920 covers a 4K terminal at the 3/8 preview ratio.
        max_width = 1920;
        max_height = 1080;
        # Highest-quality downscale; the 4K sources are cached after the first
        # preview, so the extra CPU is paid once per image.
        image_filter = "lanczos3";
        image_quality = 90;
      };
    };
  };
}
