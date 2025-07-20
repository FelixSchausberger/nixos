{pkgs, ...}: {
  imports = [
    ./functions
    ./plugins.nix
  ];

  home.packages = with pkgs; [
    grc # A generic text colouriser
  ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      # COMPLETE=fish jj | source
      direnv hook fish | source

      # Auto-start zellij if not already inside one
      # if status is-interactive; and not set -q ZELLIJ
      #   exec zellij
      # end
    '';
  };
}
