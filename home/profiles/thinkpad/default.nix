{pkgs, ...}: {
  imports = [
    ../../gui
    ../../shells
    ../../tui
  ];

  home.packages = with pkgs; [
    tlp
  ];
}
