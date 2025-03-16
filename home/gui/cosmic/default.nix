{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
    ./cosmic-files.nix
    ./cosmic-term.nix
    ./stateFile.nix
  ];

  programs.bash = {
    enable = true;

    # Auto-start cosmic when logging into TTY1
    bashrcExtra = ''
      # Check if on TTY1 and start cosmic-session if necessary
      if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
        pidof mylock > /dev/null || exec cosmic-session
      fi
    '';
  };

  programs.cosmic-manager.enable = true;

  home.packages = with pkgs; [
    cosmic-ext-ctl # CLI for COSMIC Desktop configuration management
  ];

  wayland.desktopManager.cosmic = {
    enable = true;
  };
}
