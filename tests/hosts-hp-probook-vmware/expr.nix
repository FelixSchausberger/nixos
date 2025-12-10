# Test: hp-probook-vmware host configuration builds correctly
{flake, ...}: let
  # Get the hp-probook-vmware configuration from the flake
  inherit (flake.nixosConfigurations.hp-probook-vmware) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: System is GUI-enabled
  is_gui = config.hostConfig.isGui;

  # Test: Niri window manager configured
  wm_count = builtins.length config.hostConfig.wms;
  has_niri = builtins.elem "niri" config.hostConfig.wms;

  # Test: AMD GPU profile is enabled for laptop
  amd_gpu_enabled = config.hardware.profiles.amdGpu.enable;
  amd_gpu_variant = config.hardware.profiles.amdGpu.variant;

  # Test: VMware guest integration enabled
  vmware_guest_enabled = config.virtualisation.vmware.guest.enable;
  vmware_headless = config.virtualisation.vmware.guest.headless;

  # Test: Boot loader configured for EFI
  systemd_boot_enabled = config.boot.loader.systemd-boot.enable;
  efi_can_touch_vars = config.boot.loader.efi.canTouchEfiVariables;

  # Test: System maintenance configured
  maintenance_enabled = config.modules.system.maintenance.enable;
  auto_update_enabled = config.modules.system.maintenance.autoUpdate.enable;
  monitoring_enabled = config.modules.system.maintenance.monitoring.enable;
  alerts_enabled = config.modules.system.maintenance.monitoring.alerts;

  # Test: Container support enabled
  containers_enabled = config.modules.system.containers.enable;

  # Test: Niri is enabled
  niri_enabled = config.programs.niri.enable;
}
