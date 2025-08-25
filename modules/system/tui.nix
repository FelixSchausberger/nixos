# System modules for TUI-only hosts (WSL, headless, etc.)
{
  imports = [
    ./containers.nix
    ./development.nix
    ./fonts.nix
    ./home-manager.nix
    ./maintenance.nix
    ./nix.nix
  ];
}
