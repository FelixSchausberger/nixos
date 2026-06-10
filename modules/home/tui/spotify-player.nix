{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.home.tui.spotify-player = {
    enable = lib.mkEnableOption "spotify-player";
    enableDaemon = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable spotify-player daemon for background operation";
    };
    audioBackend = lib.mkOption {
      type = lib.types.enum ["pulseaudio" "rodio"];
      default = "rodio";
      description = "Audio backend to use (rodio is pure Rust, pulseaudio integrates with PipeWire)";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.spotify-player.override {
        # Enable all modern features
        withFuzzySearch = true; # fzf feature for fuzzy search
        withNotifications = true; # notify feature for desktop notifications
        withImageSupport = true; # image feature for album art (Kitty protocol)
        withDaemon = true; # daemon feature for background operation
      };
      description = "The spotify-player package to use";
    };
  };

  config = lib.mkIf config.modules.home.tui.spotify-player.enable {
    programs.spotify-player = {
      enable = true;
      inherit (config.modules.home.tui.spotify-player) package;

      # State-of-the-art configuration for modern PipeWire setup
      settings = {
        # Spotify Connect configuration
        device = {
          name = "NixOS Spotify Player";
          device_type = "computer";
          volume = 70;
          normalize_volume = true;
          autoplay = true;
        };

        # Audio backend selection
        audio_backend = config.modules.home.tui.spotify-player.audioBackend;

        # Media control integration (works with playerctl)
        enable_media_control = true;

        # Desktop notifications (works with your WM setup)
        enable_notify = true;

        # Cover art configuration for terminal
        enable_cover_image_cache = true;
        cover_img_length = 9;
        cover_img_width = 5;

        # High-quality audio settings for modern setup
        streaming = {
          audio_quality = "VeryHigh"; # 320kbps
          normalisation = true;
          normalisation_pregain = -10.0;
          volume_controller = "software";
        };

        # App behavior optimized for desktop use
        app_config = {
          # Enable all modern features
          tracks_playback_limit = 50000;
          enable_streaming = true;
          enable_cover_image_cache = true;
          default_device = "NixOS Spotify Player";
        };

        # UI optimizations
        copy_command = {
          command = "wl-copy"; # Wayland clipboard (consistent with your Hyprland setup)
          args = [];
        };
      };
    };

    # Enable media control daemon (consistent with your Hyprland setup)
    services.playerctld.enable = true;

    # Optional daemon service for background operation
    systemd.user.services.spotify-player-daemon = lib.mkIf config.modules.home.tui.spotify-player.enableDaemon {
      Unit = {
        Description = "Spotify Player Daemon";
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${config.modules.home.tui.spotify-player.package}/bin/spotify_player --daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
