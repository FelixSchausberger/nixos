# NixOS Configuration Toggle
#
# Toggle between Determinate Nix and Standard Nix distributions
{
  # Set to true for Determinate Nix (FlakeHub + enhanced features)
  # Set to false for Standard Nix (GitHub nixos-unstable)
  #
  # Documentation:
  # - Determinate Nix: https://github.com/DeterminateSystems/determinate?tab=readme-ov-file#installing-using-our-nix-flake
  # - FlakeHub semver: https://docs.determinate.systems/flakehub/concepts/semver#nixpkgs
  #
  # After changing this setting:
  # 1. Run: nix flake lock --update-input nixpkgs --update-input nixpkgs-flakehub
  # 2. Install/uninstall the appropriate Nix distribution
  # 3. Rebuild: sudo nixos-rebuild switch --flake .
  useDeterminateNix = true;
}
