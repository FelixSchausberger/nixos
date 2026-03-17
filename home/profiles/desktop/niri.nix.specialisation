{
  config,
  pkgs,
  lib,
  ...
}: let
  safeNotifySend = import ../../lib/safe-notify-send.nix {inherit pkgs config lib;};
  safeNotifyBin = "${safeNotifySend}/bin/safe-notify-send";
in {
  # Desktop-specific niri configuration
  wm.niri = {
    enable = true;
    # Monitor configuration for desktop setup
    outputs = [
      {
        name = "Virtual-1";
        mode = {
          width = 1920;
          height = 1200;
          refresh = 60.0;
        };
        scale = 1.0;
        position = {
          x = 0;
          y = 0;
        };
      }
    ];

    # Desktop-specific application preferences
    browser = "zen";
    terminal = "ghostty";
    fileManager = "cosmic-files";

    # Desktop-specific scratchpad preferences
    scratchpad = {
      musicApp = "spotify"; # Full Spotify for desktop
      notesApp = "obsidian"; # Full note-taking app
    };
  };

  # Desktop-specific packages (gaming and productivity)
  home.packages = with pkgs; [
    # Core gaming
    steam
    lutris
    bottles

    # Performance monitoring and optimization
    mangohud
    goverlay
    gamemode
    gamescope

    # Game launchers
    prismlauncher # Minecraft

    # Emulation (temporarily disabled)
    # Track upstream fixes:
    # - dolphin-emu: Qt 6.10 incompatibility
    # - pcsx2: Qt 6.10 incompatibility
    # - rpcs3: strict-aliasing compilation errors

    # Communication
    discord

    # Tools
    winetricks
    protontricks
    steamtinkerlaunch
  ];

  # Gaming-specific systemd services
  # Note: Steam auto-start disabled for boot performance
  # Launch Steam manually via application menu or `steam` command
  systemd.user.services = {};

  # Gaming configuration files
  xdg.configFile = {
    # MangoHud configuration
    "MangoHud/MangoHud.conf".text = ''
      # Performance monitoring
      fps
      frametime
      cpu_temp
      gpu_temp
      cpu_power
      gpu_power
      ram
      vram

      # Position and appearance
      position=top-left
      width=400
      height=200
      font_size=16
      background_alpha=0.4
      alpha=0.8

      # Data logging
      output_folder=${config.home.homeDirectory}/Documents/Gaming/MangoHud
      log_duration=60
      autostart_log=0

      # Networking
      no_display=0

      # Control
      toggle_fps_limit=F1
      toggle_logging=F2
      reload_cfg=F4
      upload_log=F5
    '';

    # GameMode configuration
    "gamemode.ini".text = ''
      [general]
      renice=10
      ioprio=4
      inhibit_screensaver=1

      [filter]
      whitelist=steam
      whitelist=lutris
      whitelist=heroic
      whitelist=prismlauncher

      [gpu]
      apply_gpu_optimisations=accept-responsibility
      gpu_device=0
      amd_performance_level=high

      [custom]
      start=${safeNotifyBin} "GameMode activated"
      end=${safeNotifyBin} "GameMode deactivated"
    '';
  };

  # Create gaming directories
  home.file = {
    "${config.home.homeDirectory}/Documents/Gaming/.keep".text = "";
    "${config.home.homeDirectory}/Documents/Gaming/MangoHud/.keep".text = "";
  };
}
