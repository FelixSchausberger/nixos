# Test: desktop host configuration builds correctly
{flake, ...}: let
  # Get the desktop configuration from the flake
  inherit (flake.nixosConfigurations.desktop) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: System is GUI-enabled (desktop system)
  is_gui = config.hostConfig.isGui;

  # Test: Multiple window managers configured
  wm_count = builtins.length config.hostConfig.wm;
  has_gnome = builtins.elem "gnome" config.hostConfig.wm;
  has_hyprland = builtins.elem "hyprland" config.hostConfig.wm;
  has_niri = builtins.elem "niri" config.hostConfig.wm;

  # Test: AMD GPU profile is enabled
  amd_gpu_enabled = config.hardware.profiles.amdGpu.enable;
  amd_gpu_variant = config.hardware.profiles.amdGpu.variant;

  # Test: QMK keyboard support enabled
  qmk_enabled = config.hardware.keyboard.qmk.enable;

  # Test: System maintenance configured
  maintenance_enabled = config.modules.system.maintenance.enable;
  auto_update_enabled = config.modules.system.maintenance.autoUpdate.enable;
  monitoring_enabled = config.modules.system.maintenance.monitoring.enable;
  alerts_enabled = config.modules.system.maintenance.monitoring.alerts;
}
