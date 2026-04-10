{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.ai-assistants.opencode.notifier;

  # Detect if any window manager is enabled (graphical session required for notifications)
  hasGraphicalSession =
    config.wm.hyprland.enable
    or config.wm.niri.enable
    or config.wm.cosmic.enable
    or false;

  # Map audio backend option to package
  audioBackendPackages = {
    paplay = pkgs.pulseaudio; # paplay works with PipeWire
    inherit (pkgs) mpv;
    ffplay = pkgs.ffmpeg;
    aplay = pkgs.alsa-utils;
  };
  selectedAudioPackage = audioBackendPackages.${cfg.audioBackend} or pkgs.pulseaudio;
in {
  options.ai-assistants.opencode.notifier = {
    enable = lib.mkEnableOption "opencode-notifier plugin for system notifications and audio alerts";

    audioBackend = lib.mkOption {
      type = lib.types.enum ["paplay" "mpv" "ffplay" "aplay"];
      default = "paplay";
      description = ''
        Audio backend for playing notification sounds.
        - paplay: PulseAudio/PipeWire (recommended)
        - mpv: Media player (already in system)
        - ffplay: FFmpeg audio player
        - aplay: ALSA player
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hasGraphicalSession) {
    # Add audio backend package to environment
    # Note: notify-send is already available via wrapper at ~/.local/bin/notify-send
    home.packages = [
      selectedAudioPackage
    ];
  };
}
