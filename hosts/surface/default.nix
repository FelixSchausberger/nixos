{pkgs, ...}: {
  imports = [
    ./boot-zfs.nix
    ../../system/programs/cosmic.nix
    ./hardware-configuration.nix
  ];

  # Set kernel parameters
  boot.kernelParams = ["i915.force_probe=5916"];

  # Override vaapiIntel with enableHybridCodec
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };

  # Configure additional OpenGL packages
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiVdpau
      libvdpau-va-gl
      libcamera # Camera support
      libwacom-surface # Better stylus and touch support
      linux-firmware
      microcodeIntel
    ];
  };

  console.keyMap = "de";
}
