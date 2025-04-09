{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./boot-zfs.nix
    ../../system/programs/private
    ../../system/programs/shared
    ./hardware-configuration.nix

    # Surface-specific hardware module
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
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

  # Surface-specific configurations
  microsoft-surface.ipts.enable = true;
  microsoft-surface.surface-control.enable = true;

  console.keyMap = "de";
}
