{
  inputs,
  pkgs,
  ...
}: let
  hostLib = import ../lib.nix;
  wms = ["cosmic"];
in {
  imports =
    [
      ../shared-gui.nix
      ./hardware-configuration.nix

      # Surface-specific hardware module
      inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    ]
    ++ hostLib.wmModules wms;

  # Host-specific configuration
  hostConfig = {
    hostName = "surface";
    user = "schausberger";
    isGui = true; # Surface tablet with GUI
    wm = wms;
    system = "x86_64-linux";
  };

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
  # microsoft-surface = {
  #   ipts.enable = true;
  #   surface-control.enable = true;
  # };

  console.keyMap = "de";
}
