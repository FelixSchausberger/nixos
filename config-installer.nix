# Installer Configuration Override
#
# This is a temporary override for use during installation from the installer ISO.
# It disables FlakeHub to work around installer compatibility issues.
#
# GitHub Authentication Required:
#   The flake needs to fetch inputs from GitHub, which requires authentication.
#
#   1. Create a GitHub Personal Access Token:
#      https://github.com/settings/tokens/new
#      - Note: "NixOS Installation"
#      - Expiration: 7 days (temporary for installation)
#      - Scopes: NONE required for public repos (can leave all unchecked)
#
#   2. Set the token as an environment variable:
#      export NIX_CONFIG="access-tokens = github.com=$YOUR_TOKEN"
#
#   3. Then proceed with installation:
#      ln -sf config-installer.nix config.nix
#      sudo -E nixos-rebuild switch --flake .#hostname
#      (Note the -E flag to preserve environment variables)
#
#
# After installation, the system will automatically use the correct config.nix
# and authenticate via sops-managed secrets.
{
  # Disable Determinate Nix during installation
  useDeterminateNix = false;
}
