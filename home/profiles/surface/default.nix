{pkgs, ...}: {
  imports = [
    ../../../modules/home
    ../../../modules/home/gui/cosmic
    ../../private
  ];

  home.packages = with pkgs; [
    tlp # Advanced Power Management for Linux
  ];
}
