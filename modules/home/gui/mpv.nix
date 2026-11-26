{pkgs, ...}: {
  programs.mpv = {
    enable = true;
    defaultProfiles = ["gpu-hq"];
    scripts = [pkgs.mpvScripts.mpris];
  };

  home.packages = with pkgs; [
    ffmpeg
  ];

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "video/mp4" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];
      };
    };
  };
}
