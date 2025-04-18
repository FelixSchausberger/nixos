{pkgs, ...}: {
  programs.bat = {
    enable = true;

    extraPackages = with pkgs.bat-extras; [
      batgrep
    ];
  };

  home.shellAliases = {
    cat = "bat";
    # bg = "batgrep";
  };
}
