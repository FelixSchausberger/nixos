{
  # config,
  inputs,
  ...
}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

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

  # home.persistence."/per/home/${config.home.username}" = {
  #   directories = [
  #     {
  #       directory = ".local/share/direnv";
  #       method = "symlink";
  #     }
  #   ];
  #   allowOther = true; #  Requires programs.fuse.userAllowOther to be enabled
  # };
}
