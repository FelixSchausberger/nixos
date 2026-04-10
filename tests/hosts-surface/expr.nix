# Test: surface host configuration builds correctly
{flake, ...}: let
  # Get the surface configuration from the flake
  inherit (flake.nixosConfigurations.surface) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: System is GUI-enabled (Surface tablet)
  is_gui = config.hostConfig.isGui;

  # Test: COSMIC window manager configured
  wm_count = builtins.length config.hostConfig.wms;
  has_cosmic = builtins.elem "cosmic" config.hostConfig.wms;

  # Test: Intel graphics drivers configured
  graphics_enabled = config.hardware.graphics.enable;
  graphics_32bit_enabled = config.hardware.graphics.enable32Bit;

  # Test: Console keymap set to German
  console_keymap = config.console.keyMap;

  # Test: Intel graphics configuration present
  # Note: We check if extraPackages is defined instead of evaluating it
  # to avoid expensive derivation evaluation
  has_graphics_packages = config.hardware.graphics.extraPackages != [];
}
