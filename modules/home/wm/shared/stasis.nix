# Shared stasis configuration
# Modern Wayland idle manager with media detection
# This prevents conflicts when multiple WM modules are imported
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  niriEnabled = config.wm.niri.enable or false;
  hyprlandEnabled = config.wm.hyprland.enable or false;
  cosmicEnabled = config.programs.cosmic-session or {} != {};

  # Use graphical-session.target which is the standard for all Wayland compositors
  systemdTarget = "graphical-session.target";

  # Only enable if at least one WM is enabled
  shouldEnable = niriEnabled || hyprlandEnabled || cosmicEnabled;

  # RUNE configuration content
  runeConfig = let
    dpmsCmd =
      if niriEnabled
      then "niri msg action power-off-monitors"
      else "hyprctl dispatch dpms off";
    dpmsResumeBlock =
      if hyprlandEnabled
      # Niri auto-resumes monitors on input
      then "\n      resume_command \"hyprctl dispatch dpms on\""
      else "";
  in ''
    default:
      monitor_media true
      ignore_remote_media true
      debounce_seconds 5
      notify_before_action true
      inhibit_apps [
        "mpv"
        "vlc"
        "Spotify"
        "Music Player Daemon"
      ]

      lock_screen:
        timeout 300
        command "loginctl lock-session"
        notification "Locking in 10s"
        notify_seconds_before 10
      end

      dpms:
        timeout 60
        command "${dpmsCmd}"${dpmsResumeBlock}
      end

      suspend:
        timeout 1800
        command "systemctl suspend"
      end
    end
  '';

  stasisPackage = inputs.stasis.packages.${pkgs.stdenv.hostPlatform.system}.stasis;

  # Toggle script with OSD notification via wired/notify-send
  stasisToggle = pkgs.writeShellApplication {
    name = "stasis-toggle";
    runtimeInputs = with pkgs; [systemd libnotify];
    text = ''
      if systemctl --user is-active --quiet stasis; then
        # Notify first (stop can take time if stasis doesn't handle SIGTERM)
        notify-send -a "stasis" -u low -t 2000 -i preferences-desktop-screensaver \
          "Idle Inhibitor Disabled" \
          "System will idle normally"
        systemctl --user stop stasis &
      else
        systemctl --user start stasis
        notify-send -a "stasis" -u low -t 2000 -i caffeine-cup-full \
          "Idle Inhibitor Active" \
          "System will not idle while media is playing"
      fi
    '';
  };

  # Status script for ironbar (outputs JSON with icon based on state)
  stasisStatus = pkgs.writeShellApplication {
    name = "stasis-status";
    runtimeInputs = with pkgs; [systemd];
    text = ''
      if systemctl --user is-active --quiet stasis; then
        echo '{"text": "󰒳", "tooltip": "Idle inhibitor active - click to disable", "class": "active"}'
      else
        echo '{"text": "󰒲", "tooltip": "Idle inhibitor disabled - click to enable", "class": "inactive"}'
      fi
    '';
  };
in {
  config = lib.mkIf shouldEnable {
    # Add stasis package and helper scripts to user environment
    home.packages = [
      stasisPackage
      stasisToggle
      stasisStatus
    ];

    # Generate RUNE configuration file
    home.file.".config/stasis/stasis.rune".text = runeConfig;

    # Create systemd user service
    systemd.user.services.stasis = {
      Unit = {
        Description = "Stasis - Wayland idle manager with media detection";
        PartOf = [systemdTarget];
        After = [systemdTarget];
      };

      Service = {
        Type = "simple";
        ExecStart = "${stasisPackage}/bin/stasis";
        Restart = "on-failure";
        RestartSec = "5s";
        # Stasis doesn't handle SIGTERM properly, force quick shutdown
        TimeoutStopSec = 2;
      };

      Install = {
        WantedBy = [systemdTarget];
      };
    };
  };
}
