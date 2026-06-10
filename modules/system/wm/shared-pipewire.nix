# Shared PipeWire configuration for Wayland window managers
# Provides low-latency audio configuration used by Hyprland and Niri
_: {
  # Disable PulseAudio (using PipeWire instead)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Low-latency configuration optimized for gaming and real-time audio
    # 48kHz sample rate with 32 sample quantum for minimal latency
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock = {
          rate = 48000; # Professional audio standard
          quantum = 32; # ~0.67ms latency at 48kHz
          min-quantum = 32;
          max-quantum = 32;
        };
      };
    };
  };
}
