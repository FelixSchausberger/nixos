# Unified system modules - imports all core system functionality
# display-manager.nix self-guards with lib.mkIf (hostConfig.wms != [])
# This allows all hosts (GUI and TUI) to use same module set
{
  imports = [
    ./containers.nix
    ./deployment-validation.nix
    ./development.nix
    ./display-manager.nix
    ./emergency-shell.nix
    ./fonts.nix
    ./gaming.nix
    ./hardware/battery.nix
    ./hardware/intel-cpu.nix
    ./home-manager.nix
    ./maintenance.nix
    ./nix.nix
    ./ssl-config.nix
    ./wsl-integration.nix
  ];
}
