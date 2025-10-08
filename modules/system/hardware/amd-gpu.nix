{
  pkgs,
  lib,
  config,
  ...
}: {
  options.hardware.profiles.amdGpu = {
    enable = lib.mkEnableOption "AMD GPU configuration";

    variant = lib.mkOption {
      type = lib.types.enum ["desktop" "laptop"];
      default = "desktop";
      description = "AMD GPU variant for different form factors";
    };
  };

  config = lib.mkIf config.hardware.profiles.amdGpu.enable {
    # AMD GPU kernel modules and parameters
    boot = {
      kernelModules = ["amdgpu" "kvm-amd"];
      kernelParams =
        [
          "amdgpu.dc=1"
          "amdgpu.sg_display=0"
          "amdgpu.dpm=1"
          "amdgpu.modeset=1"
          "amd_pstate=active"
        ]
        ++ lib.optionals (config.hardware.profiles.amdGpu.variant == "desktop") [
          # Desktop-specific optimizations
          "8250.nr_uarts=0"
          "console=tty0"
          # Fix EDID detection issues - force display detection
          "amdgpu.force_detect=1"
          "drm.force_dp_encoder=true"
          "amdgpu.deep_color=1"
          "amdgpu.exp_hw_support=1"
          # USB stability improvements
          "usbcore.autosuspend=-1"
          "usb-storage.delay_use=0"
        ];
      initrd.kernelModules = ["amdgpu"];
    };

    # Graphics hardware configuration
    hardware = {
      enableRedistributableFirmware = true;

      graphics = {
        enable = true;
        enable32Bit = true;

        package = pkgs.mesa;
        package32 = pkgs.pkgsi686Linux.mesa;

        extraPackages = with pkgs; [
          libva
          vulkan-loader
          vulkan-validation-layers
          # Wayland/EGL support
          mesa
          libGL
          libGLU
          egl-wayland
          wayland
          wayland-protocols
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          libva
        ];
      };
    };

    # AMD GPU monitoring and debugging tools
    environment.systemPackages = with pkgs; [
      vulkan-tools
      glxinfo
      radeontop
    ];
  };
}
