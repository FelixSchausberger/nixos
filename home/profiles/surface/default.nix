{pkgs, ...}: {
  imports = [
    ../../../modules/home
    ../../../modules/home/gui/cosmic
    ../../../modules/home/private
  ];

  home.packages = with pkgs; [
    tlp # Advanced Power Management for Linux
  ];
}
