{pkgs, ...}: {
  programs.bat = {
    enable = true;

    extraPackages = with pkgs.bat-extras; [
      batgrep
    ];

    config = {
      theme = "base16";
    };
  };

  home.shellAliases = {
    cat = "bat";
    # bg = "batgrep";
  };
}
