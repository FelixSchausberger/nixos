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
  # programs.noctalia comes from home-manager's own module, which is loaded
  # together with the rest of modules/programs. The noctalia flake exports a
  # near-identical module; importing both declares every option twice and
  # aborts evaluation.
  config = lib.mkIf enabled {
    # Stylix theme target (HM-only). With stylix.autoEnable = false the target
    # must be enabled explicitly; it writes programs.noctalia.settings.theme and
    # customPalettes.stylix from the active base16 scheme, plus fonts/opacities
    # and the wallpaper from stylix.image.
    stylix.targets.noctalia.enable = true;

    programs.noctalia = {
      enable = true;
      # Upstream systemd user service, tied to wayland.systemd.target
      # (graphical-session.target, which contains niri-session.target). The
      # module exposes no target override, so ordering relies on the
      # graphical session being up.
      systemd.enable = true;
      # Wiring for the features noctalia takes over from the custom stack.
      # Theming stays Nix-owned (stylix writes settings.theme/palettes).
      # checkConfig (default true) fails the build on schema drift.
      settings = {
        # Blurred wallpaper behind the niri overview. Noctalia only creates
        # the noctalia-backdrop surface when this is on (upstream default:
        # off); the place-within-backdrop layer-rule is wired below.
        backdrop.enabled = true;

        # Idle management replaced stasis for full-layer shells (stasis is
        # gated off for noctalia). Mirrors the custom stack: lock at 5 min,
        # blank the screen later. Locking runs through logind, which noctalia
        # subscribes to, so the Super+Alt+L bind keeps working.
        idle.behavior.lock = {
          enabled = true;
          timeout = 300;
          action = "lock";
        };
        idle.behavior."screen-off" = {
          enabled = true;
          timeout = 660;
          action = "screen_off";
        };

        # Noctalia replaced wl-gammarelay for full-layer shells.
        nightlight.enabled = true;

        # External monitors have no backlight; brightness keys and the
        # control-center widget need the DDC/CI backend. Pairs with
        # hardware.i2c.enable on the host.
        brightness.enable_ddcutil = true;
      };
    };

    # Niri-side integration per upstream compositor guide.
    # programs.niri.settings merges with modules/home/wm/niri/default.nix.
    # Single definition block: niri-flake declares settings as one
    # attribute-set option, so split definitions conflict.
    programs.niri.settings = lib.mkIf niri {
      # Dedicated backdrop layer sits inside Niri's overview backdrop.
      # Requires [backdrop] enabled in the noctalia settings above.
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
