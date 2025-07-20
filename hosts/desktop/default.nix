{pkgs, ...}: let
  hostLib = import ../lib.nix;
  wms = ["hyprland"];
in {
  imports =
    [
      ../shared.nix
      ../boot-zfs.nix
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

  # AMD RX 6700XT GPU configuration
  hardware = {
    enableRedistributableFirmware = true;

    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;

      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

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
  };

  # AMD GPU kernel modules and parameters
  boot = {
    kernelModules = ["amdgpu" "kvm-amd"];
    kernelParams = [
      "amdgpu.dc=1"
      "amdgpu.sg_display=0"
      "amdgpu.dpm=1"
      "amdgpu.modeset=1"
      "amd_pstate=active"
    ];
    initrd.kernelModules = ["amdgpu"];
  };

  # System packages for GPU monitoring and debugging
  environment.systemPackages = with pkgs; [
    vulkan-tools
    glxinfo
    radeontop
  ];
}
