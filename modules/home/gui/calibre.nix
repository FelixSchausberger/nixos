{pkgs, ...}: {
  home.packages = with pkgs; [
    (calibre.override {
      unrarSupport = true; # Needed to open .cbr and .cbz files
    })
  ];
}
