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
    freecad
  ];

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".local/share/FreeCAD";
        method = "symlink";
      }
    ];
    allowOther = true; #  Requires programs.fuse.userAllowOther to be enabled
  };
}
