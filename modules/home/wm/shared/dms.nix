# Dank Material Shell (DMS) integration for Wayland sessions.
# DMS (quickshell/QML + Go daemon) owns the full shell layer: bar, island,
# dock, launcher, notifications, clipboard, lock screen, idle, OSD, night
# mode, and wallpaper with material-color retheming. The same custom-stack
# daemons gated for noctalia (ironbar, walker, wired, cthulock, awww,
# stasis, avizo, wl-gammarelay) gate off here too.
_sessionTarget: {
  lib,
  config,
  inputs,
  ...
}: let
  niri = config.wm.niri.enable or false;
  hyprland = config.wm.hyprland.enable or false;
  enabled = (config.wm.shell or "custom") == "dms" && (niri || hyprland);
in {
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  config = lib.mkIf enabled {
    programs.dank-material-shell = {
      enable = true;
      # Upstream systemd user unit (PartOf wayland.systemd.target, which
      # contains the compositor session target). Settings stay empty:
      # upstream defaults apply, and user-visible tuning happens through
      # the settings UI, which writes the same JSON this module owns.
      # settings.json is only generated when non-empty, so first-launch
      # state is not overwritten.
      systemd.enable = true;
      settings = {};
    };

    # niri-side integration per upstream compositor guide. programs.niri is
    # a single attribute-set option, so this whole block mirrors
    # noctalia.nix and must not conflict with it (mutually exclusive by
    # wm.shell).
    programs.niri.settings = lib.mkIf niri {
      # DMS renders its wallpaper surface on the quickshell namespace and
      # places it inside the overview backdrop; the blurwallpaper variant
      # is alternatively used when "Blur Layer" is enabled.
      layer-rules = [
        {
          matches = [{namespace = "dms:blurwallpaper";}];
          place-within-backdrop = true;
        }
        {
          matches = [{namespace = "^quickshell$";}];
          place-within-backdrop = true;
        }
      ];

      # DMS modal windows (launcher, settings, dashboards, window-rule
      # editor) share the com.danklinux.dms app id; floating matches the
      # upstream recommendation.
      window-rules = [
        {
          matches = [{app-id = "^com\\.danklinux\\.dms$";}];
          open-floating = true;
        }
      ];

      # DMS IPC binds with no niri-native equivalent. The launcher key
      # (Mod+D) is rewired in modules/home/wm/niri/keybinds.nix; Mod+Comma
      # is taken (consume-window-into-column), so settings uses Mod+Ctrl+Comma.
      binds = {
        "Mod+S".action.spawn = [
          "sh"
          "-c"
          "dms ipc call control-center toggle"
        ];
        "Mod+Ctrl+Comma".action.spawn = [
          "sh"
          "-c"
          "dms ipc call settings focusOrToggle"
        ];
      };
    };

    # On Hyprland, autostart is covered by the upstream systemd unit and
    # IPC binds live in modules/home/wm/hyprland/keybinds.nix.
  };
}
