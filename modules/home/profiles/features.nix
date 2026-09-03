{
  config,
  lib,
  pkgs,
  inputs,
  osConfig,
  ...
}: {
  options.features = {
    # Development features
    development = {
      enable = lib.mkEnableOption "development tools and environments";
      languages = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["rust" "python" "go" "nix" "javascript"]);
        default = [];
        description = "Programming languages to support";
      };
    };

    # Creative features
    creative = {
      enable = lib.mkEnableOption "creative applications and tools";
      tools = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["image" "video" "3d"]);
        default = [];
        description = "Creative tool categories to include";
      };
    };

    # Gaming features
    gaming = {
      enable = lib.mkEnableOption "gaming applications and tools";
      platforms = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["steam" "lutris" "emulation" "minecraft"]);
        default = ["steam"];
        description = "Gaming platforms to support";
      };
    };

    # Media features
    media = {
      enable = lib.mkEnableOption "media applications and services";
      services = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["music"]);
        default = [];
        description = "Media services to include";
      };
    };

    # Productivity features
    productivity = {
      enable = lib.mkEnableOption "productivity applications";
      tools = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["notes" "tasks"]);
        default = [];
        description = "Productivity tools to include";
      };
    };

    # Communication features
    communication = {
      enable = lib.mkEnableOption "communication applications";
      protocols = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["matrix"]);
        default = [];
        description = "Communication protocols to support";
      };
    };
  };

  config = {
    # Development tools
    home.packages = lib.mkMerge [
      # Development packages
      (lib.mkIf config.features.development.enable (
        with pkgs;
        # Core development tools (always included)
          [
            git
            direnv
          ]
          # Language-specific tools
          ++ lib.optionals (lib.elem "rust" config.features.development.languages) [
            rustup
            cargo-watch # Auto-rebuild on source changes (used by zellij rust layout)
            bugstalker # Modern Rust debugger with async support
          ]
          ++ lib.optionals (lib.elem "python" config.features.development.languages) [
            python3
            python3Packages.pip
            poetry
          ]
          ++ lib.optionals (lib.elem "go" config.features.development.languages) [
            go
            gopls
          ]
          ++ lib.optionals (lib.elem "nix" config.features.development.languages) [
            nil
            alejandra
            deadnix
            statix
          ]
          # Runtime only: the TypeScript/JavaScript LSP ships via the helix
          # languages module once development is enabled.
          ++ lib.optionals (lib.elem "javascript" config.features.development.languages) [
            nodejs
          ]
      ))

      # Creative packages
      (lib.mkIf config.features.creative.enable (
        with pkgs;
          lib.optionals (lib.elem "image" config.features.creative.tools) [
            krita
            inkscape
            gimp # The GNU Image Manipulation Program
          ]
          ++ lib.optionals (lib.elem "video" config.features.creative.tools) [
            ffmpeg
          ]
          ++ lib.optionals (lib.elem "3d" config.features.creative.tools) [
            blender
            freecad # 3D CAD software
            prusa-slicer # G-code generator for 3D printer
          ]
      ))

      # Gaming packages
      (lib.mkIf config.features.gaming.enable (
        with pkgs;
          lib.optionals (lib.elem "steam" config.features.gaming.platforms) [
            # Steam client comes from programs.steam (modules/system/steam.nix),
            # not a user package, so the FHS runtime and hardware udev rules apply
          ]
          ++ lib.optionals (lib.elem "lutris" config.features.gaming.platforms) [
            lutris
          ]
          ++ lib.optionals (lib.elem "emulation" config.features.gaming.platforms) [
            retroarch
            dolphin-emu
          ]
          ++ lib.optionals (lib.elem "minecraft" config.features.gaming.platforms) [
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.quantumlauncher
          ]
      ))

      # Media packages
      (lib.mkIf config.features.media.enable (
        with pkgs;
          lib.optionals (lib.elem "music" config.features.media.services) [
            # Spicetify is handled by gui/spicetify.nix (self-gated)
          ]
      ))

      # Productivity packages
      (lib.mkIf config.features.productivity.enable (
        with pkgs;
          lib.optionals (lib.elem "notes" config.features.productivity.tools) [
            # Obsidian is handled by gui/obsidian.nix (self-gated)
          ]
          ++ lib.optionals (lib.elem "tasks" config.features.productivity.tools) [
            planify # Task manager with Todoist support
            noto-fonts-emoji-blob-bin # Font needed for planify
          ]
      ))

      # Communication packages
      (lib.mkIf config.features.communication.enable (
        with pkgs;
          lib.optionals (lib.elem "matrix" config.features.communication.protocols) [
            fractal # Matrix group messaging app
          ]
      ))
    ];

    # Font configuration for planify
    fonts.fontconfig.enable = lib.mkIf config.features.productivity.enable true;

    # Development shell configurations
    programs = lib.mkIf config.features.development.enable {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      git.enable = lib.mkDefault true;
    };

    # Extra Steam library folders declared on the host via
    # modules.system.steam.extraLibraryFolders, merged into
    # libraryfolders.vdf (config copy, mirrored to the steamapps copy —
    # current clients load the steamapps copy and rewrite both on launch).
    # Steam populates apps/tallies itself on next launch. Skipped while
    # Steam runs (it rewrites the file on exit) and when a folder has no
    # steamapps dir (pool not mounted counts as absent, never created).
    # STEAM_LIBRARIES_ALLOW_RUNNING=1 overrides the running check for
    # testing only.
    home.activation.steamLibraries = let
      folders = lib.attrByPath ["modules" "system" "steam" "extraLibraryFolders"] [] osConfig;
      register = pkgs.writeShellApplication {
        name = "steam-register-libraries";
        runtimeInputs = [pkgs.python3 pkgs.procps];
        text = ''
          set -euo pipefail
          vdf="$HOME/.local/share/Steam/config/libraryfolders.vdf"
          mirror="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
          if [[ ! -f $vdf ]]; then
            echo "steam-libraries: $vdf missing (Steam never launched?), skipping"
            exit 0
          fi
          if [[ -z "''${STEAM_LIBRARIES_ALLOW_RUNNING:-}" ]] && pgrep -x steam >/dev/null; then
            echo "steam-libraries: Steam is running, skipping (close Steam and rebuild to apply)" >&2
            exit 0
          fi
          before="$(${pkgs.coreutils}/bin/md5sum "$vdf" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
          for dir in "$@"; do
            if [[ ! -d "$dir/steamapps" ]]; then
              echo "steam-libraries: $dir/steamapps missing (pool not mounted?), skipping" >&2
              continue
            fi
            ${pkgs.python3}/bin/python3 - "$vdf" "$dir" <<'PYEOF'
          import re, sys
          vdf, libdir = sys.argv[1], sys.argv[2]
          text = open(vdf, encoding="utf-8").read()
          if f'"path"\t\t"{libdir}"' in text:
              print(f"steam-libraries: {libdir} already registered")
              sys.exit(0)
          indices = [int(m) for m in re.findall(r'^\t"(\d+)"$', text, re.M)]
          if not indices:
              print("steam-libraries: no library entries found, refusing to edit", file=sys.stderr)
              sys.exit(1)
          contentid = "0"
          try:
              with open(f"{libdir}/libraryfolder.vdf", encoding="utf-8") as f:
                  m = re.search(r'"contentid"\s+"(\d+)"', f.read())
                  if m:
                      contentid = m.group(1)
          except OSError:
              pass
          stripped = text.rstrip()
          if not stripped.endswith("}"):
              print("steam-libraries: unexpected VDF tail, refusing to edit", file=sys.stderr)
              sys.exit(1)
          block = (
              f'\t"{max(indices) + 1}"\n\t{{\n'
              f'\t\t"path"\t\t"{libdir}"\n'
              '\t\t"label"\t\t""\n'
              f'\t\t"contentid"\t\t"{contentid}"\n'
              '\t\t"totalsize"\t\t"0"\n'
              '\t\t"update_clean_bytes_tally"\t\t"0"\n'
              '\t\t"time_last_update_verified"\t\t"0"\n'
              '\t\t"apps"\n\t\t{\n\t\t}\n\t}\n'
          )
          open(vdf, "w", encoding="utf-8").write(stripped[: -1] + block + "}\n")
          print(f"steam-libraries: registered {libdir}")
          PYEOF
          done
          after="$(${pkgs.coreutils}/bin/md5sum "$vdf" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
          if [[ $before != "$after" && -f $mirror ]]; then
            ${pkgs.coreutils}/bin/cp "$vdf" "$mirror"
            echo "steam-libraries: mirrored to steamapps copy"
          fi
        '';
      };
    in
      lib.mkIf (config.features.gaming.enable && lib.elem "steam" config.features.gaming.platforms && folders != []) (
        lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD ${register}/bin/steam-register-libraries ${lib.escapeShellArgs folders}
        ''
      );
  };
}
