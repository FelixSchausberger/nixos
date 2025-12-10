{
  pkgs,
  lib,
  ...
}: {
  programs.bat = {
    enable = true;

    extraPackages = with pkgs.bat-extras; [
      batgrep
    ];

    config = {
      theme = lib.mkDefault "base16";
    };
  };

  home.shellAliases = {
    cat = "bat";
    # bg = "batgrep";
  };
}
