{...}: {
  imports = [
    # Only the pieces this session needs; the full GUI app suite is reserved
    # for managed desktop hosts (see home/profiles/shared.nix).
    ../../../modules/home/gui/browsers
    ../../../modules/home/gui/terminals
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
      # Moonlight streams on the projector only; always fullscreen there.
      {
        matches = [{app-id = "^moonlight$";}];
        open-fullscreen = true;
      }
      # AirPlay (UxPlay) mirroring renders as a fullscreen overlay over the
      # desktop and disappears when mirroring stops.
      {
        matches = [{app-id = "^uxplay$";}];
        open-fullscreen = true;
      }
    ];
  };

  # The projector host has a pointer attached, and niri has no per-window
  # cursor policy: the local pointer would otherwise stay over the fullscreen
  # AirPlay/Moonlight surface. This session only exists while the projector is
  # connected, so idle hiding is effectively cast-time hiding.
  programs.niri.settings.cursor.hide-after-inactive-ms = 1000;
}
