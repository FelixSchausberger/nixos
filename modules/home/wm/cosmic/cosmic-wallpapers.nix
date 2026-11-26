{
  cosmicLib,
  inputs,
  ...
}: {
  # COSMIC picks up the same published image the homepage and kiosk use, so a
  # theme switch reaches it on the next session start. COSMIC has no live
  # watcher for a file whose contents change, so rotate only within the one
  # entry; the accent color comes from COSMIC's own theme, not from Stylix.
  wayland.desktopManager.cosmic.wallpapers = [
    {
      filter_by_theme = false;
      filter_method = cosmicLib.cosmic.mkRON "enum" "Lanczos";
      output = "all";
      rotation_frequency = 600;
      sampling_method = cosmicLib.cosmic.mkRON "enum" "Alphanumeric";
      scaling_mode = cosmicLib.cosmic.mkRON "enum" "Zoom";
      source = cosmicLib.cosmic.mkRON "enum" {
        value = [
          "${inputs.self.lib.wallpapers.root}/${inputs.self.lib.wallpapers.current}"
        ];
        variant = "Path";
      };
    }
  ];
}
