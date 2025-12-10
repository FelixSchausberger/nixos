# swww coordinated wallpaper daemon configuration
# Uses graphical-session.target for UWSM-unified session management
{
  config,
  pkgs,
  lib,
  ...
}: {
  config = {
    # Enable swww package
    home.packages = [pkgs.swww];

    # swww daemon for workspace wallpapers (default namespace)
    systemd.user.services.swww-wallpaper = {
      Unit = {
        Description = "swww daemon for workspace wallpapers";
        PartOf = ["graphical-session.target"];
        Wants = ["swww-wallpaper-init.service"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    # swww daemon for blurred backdrop (backdrop namespace)
    systemd.user.services.swww-backdrop = {
      Unit = {
        Description = "swww daemon for Niri overview backdrop (blurred wallpapers)";
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.swww}/bin/swww-daemon --namespace backdrop";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    # Initialize both wallpapers on startup (synchronized)
    systemd.user.services.swww-wallpaper-init = {
      Unit = {
        Description = "Set initial synchronized wallpapers";
        After = ["swww-wallpaper.service" "swww-backdrop.service"];
        Requires = ["swww-wallpaper.service" "swww-backdrop.service"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = let
          wallpaperName = config.wallpapers.defaultWallpaper;
          regularWallpaper = config.wallpapers.available.${wallpaperName};
          blurredWallpaper = config.wallpapers.availableBlurred.${wallpaperName};
          regularPath = "${config.wallpapers.wallpaperPath}/${regularWallpaper}";
          blurredPath = "${config.wallpapers.wallpaperPath}/${blurredWallpaper}";
          initScript = pkgs.writeShellScript "swww-init" ''
            # Set workspace wallpaper (default namespace)
            ${pkgs.swww}/bin/swww img ${regularPath} --transition-type none
            # Set backdrop wallpaper (backdrop namespace)
            ${pkgs.swww}/bin/swww img --namespace backdrop ${blurredPath} --transition-type none
          '';
        in "${initScript}";
      };
    };

    # Rotate both wallpapers together (30 min schedule)
    systemd.user.timers.swww-wallpaper-rotate = {
      Unit = {
        Description = "Timer for rotating synchronized wallpapers";
      };
      Timer = {
        OnActiveSec = "30m";
        OnUnitActiveSec = "30m";
        Unit = "swww-wallpaper-rotate.service";
      };
      Install.WantedBy = ["timers.target"];
    };

    systemd.user.services.swww-wallpaper-rotate = {
      Unit = {
        Description = "Rotate synchronized wallpapers";
      };
      Service = {
        Type = "oneshot";
        ExecStart = let
          wallpaperDir = config.wallpapers.wallpaperPath;
          # Get all wallpaper names
          wallpaperNames = lib.attrNames config.wallpapers.available;
          # Create script that picks random wallpaper and updates both
          rotateScript = pkgs.writeShellScript "rotate-wallpapers" ''
            # Array of wallpaper names
            names=(${lib.concatStringsSep " " wallpaperNames})
            # Pick random name
            random_name="''${names[$RANDOM % ''${#names[@]}]}"

            # Get paths for this wallpaper
            case "$random_name" in
              ${lib.concatStringsSep "\n              " (map (name: ''
                "${name}")
                  regular="${wallpaperDir}/${config.wallpapers.available.${name}}"
                  blurred="${wallpaperDir}/${config.wallpapers.availableBlurred.${name}}"
                  ;;
              '')
              wallpaperNames)}
            esac

            # Update both wallpapers with fade transition
            ${pkgs.swww}/bin/swww img "$regular" --transition-type fade --transition-duration 2
            ${pkgs.swww}/bin/swww img --namespace backdrop "$blurred" --transition-type fade --transition-duration 2
          '';
        in "${rotateScript}";
      };
    };
  };
}
