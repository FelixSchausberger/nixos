# modules/home/cli-tools.nix
{ pkgs, inputs, ... }: {
  # This module makes external inputs like 'inputs.localScripts' available.
  # Ensure 'inputs' is correctly passed down if this module is imported by another
  # module that doesn't automatically receive 'inputs'.
  # However, top-level home-manager configurations usually get `inputs` via specialArgs.

  home.packages = with pkgs; [
    # Assumes the package exposed by tools/scripts/flake.nix as 'default'
    # provides a binary named 'scraper' (as per its Cargo.toml).
    inputs.localScripts.packages.${pkgs.system}.default
  ];
}
