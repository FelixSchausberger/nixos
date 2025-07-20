{
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo;
in {
  imports = [
    ../shells/fish/functions/jj.nix
  ];

  home.packages = with pkgs; [
    jjui # A TUI for Jujutsu VCS
    lazyjj # Lazygit-style TUI for Jujutsu (recommended)
  ];

  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        inherit (personalInfo) name;
        email = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
      };
    };
  };
}
