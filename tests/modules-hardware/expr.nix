# Test: hardware profiles produce expected configuration
{flake, ...}: let
  configs = flake.nixosConfigurations;
in {
  # Desktop: AMD GPU profile
  desktop = {
    amd_gpu_enabled = configs.desktop.config.hardware.profiles.amdGpu.enable;
    amd_gpu_variant = configs.desktop.config.hardware.profiles.amdGpu.variant;
    # AMD GPU kernel modules
    has_amdgpu_module = builtins.elem "amdgpu" configs.desktop.config.boot.kernelModules;
    has_kvm_amd = builtins.elem "kvm-amd" configs.desktop.config.boot.kernelModules;
    # AMD GPU in initrd
    has_amdgpu_initrd = builtins.elem "amdgpu" configs.desktop.config.boot.initrd.kernelModules;
    # Graphics stack enabled
    graphics_enabled = configs.desktop.config.hardware.graphics.enable;
    graphics_32bit = configs.desktop.config.hardware.graphics.enable32Bit;
    # Desktop-specific kernel params present
    has_amdgpu_dc = builtins.any (p: builtins.match "amdgpu\\.dc=.*" p != null) configs.desktop.config.boot.kernelParams;
  };

  # Desktop: power management profile
  desktop_power = {
    power_management_enabled = configs.desktop.config.hardware.profiles.powerManagement.enable;
    power_lan_interface = configs.desktop.config.hardware.profiles.powerManagement.lanInterface;
    # auto-cpufreq service should exist
    has_autocpufreq = builtins.hasAttr "auto-cpufreq" configs.desktop.config.systemd.services;
    # wol-lan service should exist
    has_wol_lan = builtins.hasAttr "wol-lan" configs.desktop.config.systemd.services;
  };

  # m920q: power management profile
  m920q_power = {
    power_management_enabled = configs.m920q.config.hardware.profiles.powerManagement.enable;
    power_lan_interface = configs.m920q.config.hardware.profiles.powerManagement.lanInterface;
    power_suppress_leds = configs.m920q.config.hardware.profiles.powerManagement.suppressLeds;
    has_autocpufreq = builtins.hasAttr "auto-cpufreq" configs.m920q.config.systemd.services;
    has_wol_lan = builtins.hasAttr "wol-lan" configs.m920q.config.systemd.services;
  };
}
