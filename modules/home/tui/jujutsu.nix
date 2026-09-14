{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo;
in {
  imports = [
    ../shells/fish/functions/jj.nix
  ];

  # The OpenCode V2 launcher runs with XDG_CONFIG_HOME=~/.config/opencode-v2,
  # which hides the standard config directories from the tools it starts (jj
  # loses its identity, gh loses its auth). Point both at their real locations
  # explicitly so they keep working inside an OpenCode session.
  home.sessionVariables = {
    JJ_CONFIG = "${config.xdg.configHome}/jj/config.toml";
    GH_CONFIG_DIR = "${config.xdg.configHome}/gh";
  };

  home.packages = with pkgs;
    [
      gh # GitHub CLI — needed by jjpush for PR creation
      jjui # A TUI for Jujutsu VCS
      # lazyjj # Lazygit-style TUI for Jujutsu (commented out due to test failures)
    ]
    ++ [
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.jj-lsp # Conflict resolution LSP for jj
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
