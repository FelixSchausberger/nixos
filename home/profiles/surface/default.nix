{pkgs, ...}: {
  imports = [
    # Private/personal configuration
    ../../../modules/home/private
  ];

  home.packages = with pkgs; [
    tlp # Advanced Power Management for Linux
  ];
}
