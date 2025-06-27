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
    (calibre.override {
      unrarSupport = true; # Needed to open .cbr and .cbz files
    })
  ];

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".config/calibre";
      }
    ];
  };
}
