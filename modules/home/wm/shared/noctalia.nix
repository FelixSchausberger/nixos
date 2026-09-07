# Noctalia desktop shell integration for Wayland sessions.
# Noctalia (native C++) owns the full shell layer: bar, dock, launcher,
# control center, notifications, wallpaper/backdrop, lock screen, idle, OSD,
# tray, and clipboard. The custom-stack daemons for those surfaces
# (ironbar, walker, wired, cthulock, awww, stasis, avizo, wl-gammarelay)
# gate themselves off when wm.shell == "noctalia".
# sessionTarget is accepted for call-site symmetry with the other shell
# modules; autostart uses the upstream graphical-session unit.
_sessionTarget: {
  lib,
  config,
  inputs,
  pkgs,
  ...
}: let
  niri = config.wm.niri.enable or false;
  hyprland = config.wm.hyprland.enable or false;
  enabled = (config.wm.shell or "custom") == "noctalia" && (niri || hyprland);
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = lib.mkIf enabled {
    programs.noctalia = {
      enable = true;
      # Upstream systemd user service (bound to graphical-session.target,
      # which contains niri-session.target). The flake module exposes no
      # target override (unlike the nixpkgs module), so ordering relies on
      # the graphical session being up.
      systemd.enable = true;
      # Minimal settings: upstream defaults apply. validateConfig (default
      # true) fails the build on schema drift, which is the desired trial
      # signal. Theming stays Nix-owned via future [theme.templates].
      settings = {};
    };

    # Niri-side integration per upstream compositor guide.
    # programs.niri.settings merges with modules/home/wm/niri/default.nix.
    # Single definition block: niri-flake declares settings as one
    # attribute-set option, so split definitions conflict.
    programs.niri.settings = lib.mkIf niri {
      # Dedicated backdrop layer sits inside Niri's overview backdrop.
      # Requires [niri.backdrop] enabled in noctalia settings (default).
      layer-rules = [
        {
          matches = [{namespace = "^noctalia-backdrop";}];
          place-within-backdrop = true;
        }
      ];

      window-rules = [
        {
          matches = [{app-id = "^dev\\.noctalia\\.Noctalia$";}];
          open-floating = true;
        }
      ];

      # Core Noctalia IPC binds with no niri-native equivalent. The
      # launcher key (Mod+D) is rewired in modules/home/wm/niri/keybinds.nix.
      # Mod+Comma is taken (consume-window-into-column), so settings uses
      # Mod+Ctrl+Comma.
      binds = {
        "Mod+S".action.spawn = [
          "sh"
          "-c"
          "noctalia msg panel-toggle control-center"
        ];
        "Mod+Ctrl+Comma".action.spawn = [
          "sh"
          "-c"
          "noctalia msg settings-toggle"
        ];
      };
    };

    # Hyprland-side autostart is covered by the upstream systemd service;
    # IPC binds for hyprland live in modules/home/wm/hyprland/keybinds.nix.
    home.packages = lib.mkIf hyprland [
      inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
