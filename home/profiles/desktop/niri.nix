{
  config,
  pkgs,
  lib,
  ...
}: {
  # Desktop-specific niri configuration
  wm.niri = {
    enable = true;
    # Monitor configuration for desktop setup
    # 2400x1080 matches Pixel 9a landscape resolution for zero-black-bar Moonlight streaming
    outputs = [
      {
        name = "VIRTUAL-1";
        mode = {
          width = 2400;
          height = 1080;
          refresh = 60.0;
        };
        scale = 1.0;
        position = {
          x = 0;
          y = 0;
        };
      }
    ];

    # Window rules for various applications
    windowRules = let
      rule = title: appId: extraConfig:
        {
          matches =
            lib.optional (title != "") {
              title = "^${lib.escapeRegex title}$";
            }
            ++ lib.optional (appId != "") {
              "app-id" = "^${lib.escapeRegex appId}$";
            };
        }
        // extraConfig;
    in [
      # Gaming: Steam, MangoHud, and game launchers - open on workspace 1
      (rule "Steam" "steam" {open-on-workspace = "1";})
      (rule "Steam Big Picture" "steam" {open-on-workspace = "1";})
      (rule "" "steam" {open-on-workspace = "1";})
      (rule "MangoHud" "mangohud" {open-on-workspace = "1";})
      (rule "Lutris" "lutris" {open-on-workspace = "1";})
      (rule "Heroic Games Launcher" "heroic" {open-on-workspace = "1";})

      # Moonlight streaming - fullscreen on workspace 1
      (rule "Moonlight" "moonlight" {open-on-workspace = "1";})

      # Steam clients - always open on VIRTUAL-1 for Moonlight streaming
      (rule "Steam" "steam" {open-on-output = "VIRTUAL-1";})
      (rule "Steam Big Picture" "steam" {open-on-output = "VIRTUAL-1";})

      # Chat and communication - open on workspace 2
      (rule "Discord" "discord" {open-on-workspace = "2";})

      # Browsers - open on workspace 3
      (rule "Zen Browser" "zen" {open-on-workspace = "3";})
      (rule "Firefox" "firefox" {open-on-workspace = "3";})

      # Development tools - open on workspace 5
      (rule "Code" "code" {open-on-workspace = "5";})

      # File managers and utilities - open on current workspace
      (rule "Nautilus" "nautilus" {open-on-workspace = "focused";})
      (rule "org.gnome.Nautilus" "nautilus" {open-on-workspace = "focused";})

      # Media players - open on workspace 7
      (rule "mpv" "mpv" {open-on-workspace = "7";})
      (rule "spotify" "spotify" {open-on-workspace = "7";})
    ];
  };

  # Focus VIRTUAL-1 at startup so Moonlight/Sunshine input reaches Steam on it
  programs.niri.settings.spawn-at-startup = [
    {
      command = [
        "${pkgs.bash}/bin/bash"
        "-c"
        ''
          # Wait for niri to be ready, then focus the virtual output
          while ! ${pkgs.niri}/bin/niri msg action focus-monitor VIRTUAL-1 2>/dev/null; do
            sleep 0.2
          done
        ''
      ];
    }
  ];

  # Gaming: tools and configurations for Moonlight streaming
  home.packages = with pkgs; [
    # Moonlight game streaming client
    moonlight-qt

    # MangoHud for FPS monitoring and performance overlay
    mangohud
  ];

  # Create gaming directories
  home.file = {
    "${config.home.homeDirectory}/Documents/Gaming/.keep".text = "";
    "${config.home.homeDirectory}/Documents/Gaming/MangoHud/.keep".text = "";
  };
}
