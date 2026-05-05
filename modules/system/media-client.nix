{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.modules.system.mediaClient;
in {
  options.modules.system.mediaClient = {
    enable = lib.mkEnableOption "media client support (VAAPI hardware decode, Moonlight streaming client)";
  };

  config = lib.mkIf cfg.enable {
    # Enable the full graphics stack for VAAPI hardware decode.
    # The Intel UHD 630 iGPU in the i7-8700T supports VAAPI via the iHD driver.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # VAAPI driver configuration: use intel-media-driver (iHD) for Gen8+ Intel GPUs.
    # The iHD driver supports H.264, H.265/HEVC, VP8, VP9 decode on Coffee Lake GT2.
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override {
        enableHybridCodec = true;
      };
    };

    # Additional VAAPI and graphics packages for the UHD 630 iGPU.
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver # VAAPI iHD driver for Gen8+ Intel iGPUs
      libva-utils # vainfo, vainfo2 — query VAAPI caps
      libva-vdpau-driver # VAAPI->VDPAU bridge (for apps that need VDPAU)
      libvdpau-va-gl # OpenGL+VAAPI bridge
    ];

    environment.systemPackages = with pkgs; [
      # Moonlight streaming client with VAAPI hardware decode.
      moonlight-qt
    ];
  };
}
