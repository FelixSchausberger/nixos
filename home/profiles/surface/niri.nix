# Surface niri session: same shell stack as the homelab m920q (wm.shell
# defaults to "custom": ironbar, walker, wired, waylock, awww, stasis).
_: {
  wm.niri = {
    enable = true;
    browser = "zen";
    terminal = "ghostty";

    # 12.3" 2736x1824 internal panel at ~267 ppi: scale 2 keeps UI at a
    # comfortable logical size and matches the tablet's touch targets.
    outputs = [
      {
        name = "eDP-1";
        scale = 2.0;
      }
    ];
  };
}
