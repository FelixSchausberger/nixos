# System modules for TUI-only hosts (WSL, headless, etc.)
{
  imports = [
    ./containers.nix
    ./development.nix
    ./emergency-shell.nix
    ./fonts.nix
    ./home-manager.nix
    ./maintenance.nix
    ./nix.nix
    ./wsl-integration.nix
  ];
}
