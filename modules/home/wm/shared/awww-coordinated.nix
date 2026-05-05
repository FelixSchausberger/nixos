# awww coordinated wallpaper daemon configuration
# Options-based module: enabled and configured via wm.awww options.
# graphical-session.target activates before WAYLAND_DISPLAY is set, causing
# awww-daemon to default to wayland-0 and fail to connect. Use a WM-specific
# session target (e.g. niri-session.target) instead.
#
# This module should be imported once. Configure via:
#   wm.awww.enable = true;
#   wm.awww.sessionTarget = "<wm>-session.target";
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.wm.awww;
in {
  options.wm.awww = {
    enable = lib.mkEnableOption "awww coordinated wallpaper daemon";

    sessionTarget = lib.mkOption {
      type = lib.types.str;
      description = "Systemd user target to bind awww services to";
      example = "niri-session.target";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.awww];

    # awww daemon for workspace wallpapers (default namespace)
    systemd.user.services.awww-wallpaper = {
      Unit = {
        Description = "awww daemon for workspace wallpapers";
        After = [cfg.sessionTarget];
        PartOf = [cfg.sessionTarget];
        Wants = ["awww-wallpaper-init.service"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [cfg.sessionTarget];
    };

    # awww daemon for blurred backdrop (backdrop namespace)
    systemd.user.services.awww-backdrop = {
      Unit = {
        Description = "awww daemon for Niri overview backdrop (blurred wallpapers)";
        After = [cfg.sessionTarget];
        PartOf = [cfg.sessionTarget];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.awww}/bin/awww-daemon --namespace backdrop";
        Restart = "on-failure";
      };
      Install.WantedBy = [cfg.sessionTarget];
    };

    # Initialize both wallpapers on startup (synchronized)
    systemd.user.services.awww-wallpaper-init = {
      Unit = {
        Description = "Set initial synchronized wallpapers";
        After = [
          "awww-wallpaper.service"
          "awww-backdrop.service"
        ];
        Requires = [
          "awww-wallpaper.service"
          "awww-backdrop.service"
        ];
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
          initScript = pkgs.writeShellScript "awww-init" ''
                          # Wait for default-namespace daemon socket to be ready
                          until ${pkgs.awww}/bin/awww query 2>/dev/null; do
                            ${pkgs.coreutils}/bin/sleep 0.1
                          done

                          # Wait for backdrop-namespace daemon socket to be ready
            until ${pkgs.awww}/bin/awww query --namespace backdrop 2>/dev/null; do
                          ${pkgs.coreutils}/bin/sleep 0.1
                        done

                          # Set workspace wallpaper (default namespace)
                          ${pkgs.awww}/bin/awww img ${regularPath} --transition-type none
                          # Set backdrop wallpaper (backdrop namespace)
                          ${pkgs.awww}/bin/awww img --namespace backdrop ${blurredPath} --transition-type none
          '';
        in "${initScript}";
      };
    };

    # Rotate both wallpapers together (30 min schedule)
    systemd.user.timers.awww-wallpaper-rotate = {
      Unit = {
        Description = "Timer for rotating synchronized wallpapers";
      };
      Timer = {
        # Run shortly after session start to handle late-appearing outputs
        # (e.g. DP monitors that come up after compositor initialization).
        OnActiveSec = "20s";
        OnUnitActiveSec = "30m";
        Unit = "awww-wallpaper-rotate.service";
      };
      Install.WantedBy = ["timers.target"];
    };

    systemd.user.services.awww-wallpaper-rotate = {
      Unit = {
        Description = "Rotate synchronized wallpapers";
      };
      Service = {
        Type = "oneshot";
        ExecStart = let
          wallpaperDir = config.wallpapers.wallpaperPath;
          wallpaperNames = lib.attrNames config.wallpapers.available;
          rotateScript = pkgs.writeShellScript "rotate-wallpapers" ''
            # Array of wallpaper names
            names=(${lib.concatStringsSep " " wallpaperNames})
            # Pick random name
            random_name="''${names[$RANDOM % ''${#names[@]}]}"

            # Get paths for this wallpaper
            case "$random_name" in
              ${lib.concatStringsSep "\n              " (
              map (name: ''
                "${name}")
                  regular="${wallpaperDir}/${config.wallpapers.available.${name}}"
                  blurred="${wallpaperDir}/${config.wallpapers.availableBlurred.${name}}"
                  ;;
              '')
              wallpaperNames
            )}
            esac

            # Update both wallpapers with fade transition
            ${pkgs.awww}/bin/awww img "$regular" --transition-type fade --transition-duration 2
            ${pkgs.awww}/bin/awww img --namespace backdrop "$blurred" --transition-type fade --transition-duration 2
          '';
        in "${rotateScript}";
      };
    };
  };
}
