# Configures shared command-line tools, including 'scraper' from ./home/scripts.
{ pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    inputs.localScripts.packages.${pkgs.system}.default
  ];
}
