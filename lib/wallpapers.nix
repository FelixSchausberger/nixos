# Canonical wallpaper set, filenames only (files live in
# modules/home/wallpapers). Shared so the Home Manager wallpaper module and the
# Homepage dashboard background cannot drift: the dashboard follows the window
# manager's default wallpaper but must not use the blurred overview variant,
# which carries a soft frame meant for the niri overview backdrop.
rec {
  # Wallpaper the window manager starts on and the dashboard follows.
  default = "solar-system";

  # Name -> crisp file, used as the desktop wallpaper.
  available = {
    solar-system = "solar-system.jpg";
    the-whale = "the-whale.jpg";
    appa = "appa.jpg";
  };

  # Name -> blurred file, used as the overview backdrop (niri).
  blurred = {
    solar-system = "solar-system_blurred.jpg";
    the-whale = "the-whale_blurred.jpg";
    appa = "appa_blurred.jpg";
  };
}
