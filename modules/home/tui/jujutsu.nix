{pkgs, ...}: {
  imports = [
    ../shells/fish/functions/jj.nix
  ];

  home.packages = with pkgs; [
    jjui # A TUI for Jujutsu VCS
  ];

  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "Felix Schausberger";
        email = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
      };
    };
  };
}
