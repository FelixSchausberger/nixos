# Host profile detection and static profile imports
let
  # Base profiles included for all hosts
  baseProfiles = [
    ../home/profiles/default/00-shared.nix
    ../home/profiles/default/10-features.nix
  ];

  # Static profile import map
  # Replaces dynamic readDir with explicit lists for better evaluation performance
  profileMap = {
    desktop =
      baseProfiles
      ++ [
        ../home/profiles/desktop/default.nix
        ../home/profiles/desktop/hyprland.nix
        ../home/profiles/desktop/niri.nix
      ];

    surface =
      baseProfiles
      ++ [
        ../home/profiles/surface/default.nix
      ];

    portable =
      baseProfiles
      ++ [
        ../home/profiles/portable/default.nix
      ];

    hp-probook-wsl =
      baseProfiles
      ++ [
        ../home/profiles/hp-probook-wsl/default.nix
      ];

    hp-probook-vmware =
      baseProfiles
      ++ [
        ../home/profiles/hp-probook-vmware/default.nix
      ];
  };
in {
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

  # Get profile imports for a specific host (replaces importProfile from lib/import.nix)
  getProfileImports = hostName:
    profileMap.${hostName} or baseProfiles;
}
