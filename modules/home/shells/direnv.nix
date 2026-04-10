_: {
  programs.bash = {
    enable = true;

    bashrcExtra = ''
      eval "$(direnv hook bash)"
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
