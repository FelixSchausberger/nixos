{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo defaults;

  ocws = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ocws;

  # Single-line badge the starship prompt renders; written by the ocws-gc
  # timer below so the prompt never pays for the jj classification itself.
  badgeFile = "${config.xdg.cacheHome}/ocws/badge";
in {
  imports = [
    ../shells/fish/functions/jj.nix
  ];

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

  # Reclaim finished jj workspaces daily and refresh the prompt badge. The
  # classification is jj against main@origin, so the job runs from the primary
  # checkout and no-ops on a host that lacks it. `ocws gc` fetches, keeps
  # unpushed/in-flight/conflicted workspaces and any workspace with a live
  # process, and reclaims empty/merged ones past the age gate.
  systemd.user.services.ocws-gc = {
    Unit.Description = "Reclaim finished jj workspaces and refresh the ocws status badge";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "ocws-gc" ''
        set -euo pipefail
        repo=${lib.escapeShellArg defaults.paths.nixosConfig}
        badge=${lib.escapeShellArg badgeFile}
        [ -d "$repo" ] || exit 0
        cd "$repo"
        ${ocws}/bin/ocws gc
        read -r total empty merged unpushed inflight conflict stale < <(${ocws}/bin/ocws ls --counts)
        attention=$((unpushed + conflict))
        out=""
        if [ "$stale" -gt 0 ]; then out="🧹$stale "; fi
        if [ "$attention" -gt 0 ]; then out="$out⇡$attention "; fi
        mkdir -p "$(dirname "$badge")"
        printf '%s' "$out" > "$badge"
      '');
    };
  };
  systemd.user.timers.ocws-gc = {
    Install.WantedBy = ["timers.target"];
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
