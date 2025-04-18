{pkgs, ...}: {
  imports = [
    ../../shared
    ../../shared/gui/cosmic
    ../../private
  ];

  home.packages = with pkgs; [
    tlp # Advanced Power Management for Linux
  ];
}
