# Unified system modules - imports all core system functionality
# display-manager.nix guards with lib.mkIf (hostConfig.wms != [])
# so headless hosts (wms = []) get no display manager or graphics stack
{
  imports = [
    ./containers.nix
    ./deployment-validation.nix
    ./development.nix
    ./display-manager.nix
    ./emergency-shell.nix
    ./fonts.nix
    ./hardware/battery.nix
    ./hardware/intel-cpu.nix
    ./home-manager.nix
    ./maintenance.nix
    ./nix.nix
    ./ssl-config.nix
    ./wsl-integration.nix
  ];
}
