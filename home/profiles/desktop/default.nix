{pkgs, ...}: {
  imports = [
    # Private/personal configuration
    ../../../modules/home/private

    # Desktop-specific applications
    ../../../modules/home/private/gui/freecad.nix # General purpose Open Source 3D CAD/MCAD/CAx/CAE/PLM modeler
    ../../../modules/home/private/gui/steam.nix # A digital distribution platform
    ../../../modules/home/private/gui/prusaslicer.nix # G-code generator for 3D printer
  ];

  home.packages = with pkgs; [
    # Gaming and emulation
    linuxKernel.packages.linux_zen.xpadneo # Advanced Linux driver for Xbox One wireless controllers
    lutris # Open Source gaming platform for GNU/Linux
    wineWowPackages.waylandFull # An Open Source implementation of the Windows API on top of X, OpenGL, and Unix
  ];
}
