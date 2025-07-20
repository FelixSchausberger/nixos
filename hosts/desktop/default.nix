{pkgs, ...}: let
  hostLib = import ../lib.nix;
  wms = ["hyprland"];
in {
  imports =
    [
      ../shared.nix
      ./boot-zfs.nix
      ./hardware-configuration.nix
    ]
    ++ hostLib.wmModules wms;

  # Host-specific configuration
  hostConfig = {
    hostName = "desktop";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;

      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      # AMD RX 6700XT GPU configuration
      extraPackages = with pkgs; [
        libva
        vulkan-loader
        vulkan-validation-layers
        amdvlk
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        libva
        amdvlk
      ];
    };
    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;
  };

  # System packages for GPU monitoring and debugging
  environment.systemPackages = with pkgs; [
    vulkan-tools
    glxinfo
    radeontop
  ];
}
