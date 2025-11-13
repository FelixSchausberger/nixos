_sessionTarget: {
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.wm.shared.wallpaper;
  in
    lib.mkIf cfg.enable {
      # Create wallpapers directory
      home.file = {
        ".config/wallpapers/.keep".text = "";
      };
    };
}
