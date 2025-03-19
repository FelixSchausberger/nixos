{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  home.packages = with pkgs; [
    planify # Task manager with Todoist support
    noto-fonts-emoji-blob-bin # Needed for planify
  ];

  fonts.fontconfig.enable = true;

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".local/share/io.github.alainm23.planify";
      }
    ];
  };
}
