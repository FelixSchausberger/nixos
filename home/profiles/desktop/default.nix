{
  lib,
  pkgs,
  ...
}: {
  imports = [];

  # Seed Lutris game entries for the manually-installed Windows games
  # (slugs must match the lutris:rungame/<slug> Moonlight tiles from
  # modules/system/emulation.nix). Copies each seed only when absent so
  # Lutris owns the files afterwards and user edits survive rebuilds.
  # Wine prefixes are created under /per/mnt/games/Lutris/prefixes on first
  # launch; a Wine runner must be installed once via the Lutris GUI.
  home.activation.lutrisSeedGames = lib.hm.dag.entryAfter ["writeBoundary"] ''
    seeds="${./lutris-games}"
    target="$HOME/.config/lutris/games"
    mkdir -p "$target"
    for seed in "$seeds"/*.yml; do
      name="$(basename "$seed")"
      if [[ ! -f "$target/$name" ]]; then
        $DRY_RUN_CMD cp "$seed" "$target/$name"
        echo "lutris-seed: installed $name"
      fi
    done
  '';

  # Feature-based configuration for desktop
  features = {
    development = {
      enable = true;
      languages = [
        "nix"
        "rust"
        "python"
      ];
    };

    creative = {
      enable = true;
      tools = [
        "image"
        "3d"
        "video"
      ];
    };

    gaming = {
      enable = true;
      # lutris comes from modules/system/emulation.nix instead: Moonshine
      # launches tiles with the system PATH, so its binary must be a system
      # package, not a home package.
      platforms = [
        "steam"
        "minecraft"
      ];
    };

    media = {
      enable = true;
      services = ["music"];
    };

    productivity = {
      enable = true;
      tools = [
        "notes"
        "tasks"
      ];
    };

    communication = {
      enable = true;
      protocols = ["matrix"];
    };
  };

  home = {
    packages = with pkgs; [
      # Desktop-specific hardware support
      linuxKernel.packages.linux_zen.xpadneo # Advanced Linux driver for Xbox One wireless controllers
      wineWow64Packages.waylandFull # An Open Source implementation of the Windows API on top of X, OpenGL, and Unix
      libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
      vial # Open-source GUI and QMK fork for configuring your keyboard in real time
    ];
  };
}
