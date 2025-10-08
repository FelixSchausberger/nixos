{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.applets = {
    audio.settings = {
      show_media_controls_in_top_panel = true;
    };

    app-list.settings = {
      enable_drag_source = true;
      favorites = [
        "firefox"
        "com.system76.CosmicFiles"
        "com.system76.CosmicEdit"
        "com.system76.CosmicTerm"
        "com.system76.CosmicSettings"
      ];
      filter_top_levels = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "ActiveWorkspace");
    };

    time.settings = {
      first_day_of_week = 0;
      military_time = true;
      show_date_in_top_panel = true;
      show_seconds = false;
      show_weekday = true;
    };
  };
}
