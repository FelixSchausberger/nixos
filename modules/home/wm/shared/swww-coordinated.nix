# swww coordinated wallpaper daemon configuration
# Parametrized by sessionTarget (e.g. "wayland-session@niri.target") so daemons start
# after the compositor exports WAYLAND_DISPLAY to the systemd environment.
# graphical-session.target activates before WAYLAND_DISPLAY is set, causing
# swww-daemon to default to wayland-0 and fail to connect.
#
# This module should ONLY be imported once per system, not multiple times.
# Import from only ONE WM module (e.g., only from hyprland OR niri, not both).
sessionTarget: {
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
        After = [sessionTarget];
        PartOf = [sessionTarget];
        Wants = ["swww-wallpaper-init.service"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [sessionTarget];
    };

    # swww daemon for blurred backdrop (backdrop namespace)
    systemd.user.services.swww-backdrop = {
      Unit = {
        Description = "swww daemon for Niri overview backdrop (blurred wallpapers)";
        After = [sessionTarget];
        PartOf = [sessionTarget];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.swww}/bin/swww-daemon --namespace backdrop";
        Restart = "on-failure";
      };
      Install.WantedBy = [sessionTarget];
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
        Restart = "on-failure";
        RestartSec = "2s";
        ExecStart = let
          wallpaperName = config.wallpapers.defaultWallpaper;
          regularWallpaper = config.wallpapers.available.${wallpaperName};
          blurredWallpaper = config.wallpapers.availableBlurred.${wallpaperName};
          regularPath = "${config.wallpapers.wallpaperPath}/${regularWallpaper}";
          blurredPath = "${config.wallpapers.wallpaperPath}/${blurredWallpaper}";
          initScript = pkgs.writeShellScript "swww-init" ''
            # Wait for default-namespace daemon socket to be ready
            until ${pkgs.swww}/bin/swww query 2>/dev/null; do
              sleep 0.1
            done

            # Wait for backdrop-namespace daemon socket to be ready
            until ${pkgs.swww}/bin/swww query --namespace backdrop 2>/dev/null; do
              sleep 0.1
            done

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
