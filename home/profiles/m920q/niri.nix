{inputs, ...}: {
  imports = [
    # Only the pieces this session needs; the full GUI app suite is reserved
    # for managed desktop hosts (see home/profiles/shared.nix).
    ../../../modules/home/gui/browsers
    ../../../modules/home/gui/terminals
    ../../../modules/home/gui/media-kiosk.nix
    ../../persistence.nix
  ];

  # m920q projector session: a normal niri session, started on demand by
  # modules.system.sessionOnDemand when the projector is hotplugged. Monitor
  # auto-detection is used since output names vary (HDMI-A-1, DP-1, ...).
  wm.niri = {
    enable = true;
    browser = "zen";
    terminal = "ghostty";

    # VIRTUAL-1 is the vkms headless output; keep content on the real display.
    outputs = [
      {
        name = "VIRTUAL-1";
        enable = false;
      }
    ];

    windowRules = [
      # Moonlight streams on the projector only; always fullscreen there. The
      # Qt app-id is com.moonlight_stream.Moonlight on current releases.
      {
        matches = [{app-id = "^(moonlight|com\\.moonlight_stream\\.Moonlight)$";}];
        open-fullscreen = true;
        open-focused = true;
      }
      # Nightjar is the kiosk game library and stream client. SDL publishes
      # its reverse-DNS application id as the Wayland app id.
      {
        matches = [{app-id = "^io\\.github\\.ramazankara\\.nightjar$";}];
        open-fullscreen = true;
        open-focused = true;
      }
      # AirPlay (UxPlay) mirroring renders as a fullscreen overlay over the
      # desktop and disappears when mirroring stops. niri only displays the
      # focused fullscreen window, and a newly opened UxPlay window does not
      # take focus from a fullscreen kiosk window by itself: the mirror would
      # render behind Cinejoy and the projector would keep showing the app.
      {
        matches = [{app-id = "^uxplay$";}];
        open-fullscreen = true;
        open-focused = true;
      }
      # The kiosk shell and the chromeless app windows it opens (Cinejoy) are
      # both Zen toplevels. niri hides the top layer-shell layer (ironbar,
      # notifications) while a focused fullscreen window covers the screen.
      {
        matches = [{app-id = "^(zen|zen-beta)$";}];
        open-fullscreen = true;
      }
    ];
  };

  # Condition-aware wallpaper selection. The pool lives on the data share and
  # is sorted into the standard phase/weather folders; the selector publishes
  # current.jpg there for the dashboard and the kiosk. The collection defaults
  # live in modules/home/wallpapers/dynamic.nix.
  wallpapers.dynamic = {
    enable = true;
    roots = [inputs.self.lib.wallpapers.root];
  };

  # The 2026 Steam Controller's lizard mode maps Steam+D-pad-right to Alt+Tab
  # (the firmware emits the key combination itself). Binding it to the previous
  # window is the controller-only return path from a Cinejoy app window; a real
  # keyboard gets the same behaviour as a side effect.
  programs.niri.settings.binds."Alt+Tab".action.focus-window-previous = {};

  # The projector host has a pointer attached, and niri has no per-window
  # cursor policy: the local pointer would otherwise stay over the fullscreen
  # AirPlay/Moonlight surface. This session only exists while the projector is
  # connected, so idle hiding is effectively cast-time hiding.
  programs.niri.settings.cursor.hide-after-inactive-ms = 1000;
}
