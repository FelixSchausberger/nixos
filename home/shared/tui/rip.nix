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
    rm-improved
  ];

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".local/share/graveyard";
        method = "symlink";
      }
    ];
  };
}
