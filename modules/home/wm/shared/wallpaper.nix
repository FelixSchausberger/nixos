sessionTarget: {
  pkgs,
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.wm.shared.wallpaper;
    # Determine if this is a hyprland session based on session target
    isHyprland = lib.hasInfix "hyprland" sessionTarget;
  in
    lib.mkIf cfg.enable {
      # Include appropriate wallpaper packages
      home.packages = with pkgs; [
        swaybg
      ];

      # Swaybg service for non-hyprland compositors
      systemd.user.services.swaybg = lib.mkIf (!isHyprland) {
        Unit = {
          Description = "Wallpaper daemon for Wayland";
          After = [sessionTarget];
          PartOf = [sessionTarget];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${cfg.path} -m ${cfg.mode}";
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install.WantedBy = [sessionTarget];
      };

      # Create wallpapers directory
      home.file = {
        ".config/wallpapers/.keep".text = "";
      };
    };
}
