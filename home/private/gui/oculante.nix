{pkgs, ...}: {
  home.packages = with pkgs; [
    oculante
  ];

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "image/gif" = ["oculante.desktop"];
        "image/jpg" = ["oculante.desktop"];
        "image/jpeg" = ["oculante.desktop"];
        "image/png" = ["oculante.desktop"];
      };
    };

    desktopEntries.oculante = {
      name = "Oculante";
      exec = "${pkgs.oculante}/bin/oculante";
    };
  };
}
