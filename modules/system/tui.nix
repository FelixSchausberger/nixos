# System modules for TUI-only hosts (WSL, headless, etc.)
{
  imports = [
    ./containers.nix
    ./deployment-validation.nix
    ./development.nix
    ./emergency-shell.nix
    ./fonts.nix
    ./home-manager.nix
    ./maintenance.nix
    ./nix.nix
    ./ssl-config.nix
    ./wsl-integration.nix
  ];
}
