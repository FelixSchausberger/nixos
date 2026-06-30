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
    # lazyjj # Lazygit-style TUI for Jujutsu (commented out due to test failures)
  ];

  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        inherit (personalInfo) name;
        email = "131732042+FelixSchausberger@users.noreply.github.com"; # https://help.github.com/articles/setting-your-email-in-git/
      };

      # Git-style short aliases for frequently used commands
      aliases = {
        st = ["status"];
        d = ["diff"];
        l = ["log"];
        n = ["new"];
        e = ["edit"];
        s = ["show"];
        b = ["bookmark"];
        pull = [
          "git"
          "fetch"
        ];
      };

      # Disable auto-advancing the main bookmark on local jj new/commit operations.
      # main must only advance via jj git fetch (i.e. after a PR merges on origin).
      # Allowing auto-advance was the root cause of local main drifting ahead of origin/main.
      experimental-advance-branches = {
        enabled-branches = [];
      };
    };
  };
}
