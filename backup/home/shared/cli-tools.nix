# Configures shared command-line tools, including 'scraper' from ./home/scripts.
{ pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    # This assumes the package exposed by home/scripts/flake.nix as 'default'
    # provides a binary named 'scraper' (as per its Cargo.toml)
    inputs.localScripts.packages.${pkgs.system}.default
  ];
}
