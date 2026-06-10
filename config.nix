# NixOS Configuration Toggle
#
# Toggle Determinate Nix integration
{
  # Set to true for Determinate Nix (FlakeHub + enhanced features)
  # Set to false for Standard Nix behavior while still using FlakeHub nixpkgs
  #
  # Documentation:
  # - Determinate Nix: https://github.com/DeterminateSystems/determinate?tab=readme-ov-file#installing-using-our-nix-flake
  # - FlakeHub semver: https://docs.determinate.systems/flakehub/concepts/semver#nixpkgs
  #
  # After changing this setting:
  # 1. Install/uninstall the appropriate Nix distribution
  # 2. Rebuild: sudo nixos-rebuild switch --flake .
  useDeterminateNix = true;
}
