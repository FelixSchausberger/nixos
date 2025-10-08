# Dynamic host profile detection
{
  # Scan host configurations to determine what profiles are needed
  detectProfiles = hostConfigs: let
    # Extract profile information from each host
    profiles = builtins.map (hostConfig: {
      inherit (hostConfig.hostConfig) hostName;
      isGui = hostConfig.hostConfig.isGui or false;
      isTui = !(hostConfig.hostConfig.isGui or false);
    }) (builtins.attrValues hostConfigs);

    # Check if any host needs GUI
    needsGui = builtins.any (p: p.isGui) profiles;
    needsTui = builtins.any (p: p.isTui) profiles;
  in {
    inherit needsGui needsTui profiles;
  };

  # Helper functions for host configuration
  isTuiHost = hostConfig: !(hostConfig.hostConfig.isGui or false);
  isGuiHost = hostConfig: hostConfig.hostConfig.isGui or false;

  # Get profile type for a specific host
  getHostProfile = hostConfig:
    if hostConfig.hostConfig.isGui or false
    then "gui"
    else "tui";
}
