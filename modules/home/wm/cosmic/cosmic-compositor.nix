{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.compositor = {
    active_hint = true;
    autotile = true;
    autotile_behavior = cosmicLib.cosmic.mkRON "enum" "Global";
    cursor_follows_focus = false;
    descale_xwayland = false;
    edge_snap_threshold = 0;
    focus_follows_cursor = false;
    focus_follows_cursor_delay = 250;

    workspaces = {
      workspace_layout = cosmicLib.cosmic.mkRON "enum" "Vertical";
      workspace_mode = cosmicLib.cosmic.mkRON "enum" "OutputBound";
    };

    xkb_config = {
      model = "pc104";
      layout = "eu,de"; # EurKey and German
      variant = ",";
      options = cosmicLib.cosmic.mkRON "optional" "grp:alt_shift_toggle,terminate:ctrl_alt_bksp";
      repeat_delay = 600;
      repeat_rate = 25;
      rules = "";
    };
  };
}
