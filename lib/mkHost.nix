# Host configuration builder
{
  hostName,
  user ? "schausberger",
  wm ? "hyprland",
  system ? "x86_64-linux",
  extraModules ? [],
}: {
  # Make host configuration available to all modules
  _module.args = {
    hostConfig = {
      inherit hostName user wm system;
    };
  };

  # Standard host configuration
  networking.hostName = hostName;

  # Additional modules can be added per host
  imports = extraModules;
}
