{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo defaults;

  cfg = config.tui.jujutsu;

  # The configured wrapper from the rookery project module: the fleet values
  # (base, prefix, trunk) are baked in, and runtime ROOKERY_* still override.
  rookery = config.programs.rookery.finalPackage;
  # The board installed by the same module. It links rookery-core and renders
  # the same read model; the wrapper supplies the fleet environment and the
  # configured CLI path a seat pane re-enters.
  rookeryTui = config.programs.rookery.tui.finalPackage;
  # Single-line badge the starship prompt renders; written by the ocws-gc
  # timer below so the prompt never pays for the jj classification itself.
  badgeFile = "${config.xdg.cacheHome}/ocws/badge";

  # Digest cadence state: the last published board signature + its epoch.
  # Lives beside the badge in the cache; a clean board tears it down so a
  # later rematch of the same mess counts as a fresh transition.
  digestStateFile = "${config.xdg.cacheHome}/ocws/digest-last";

  # Board digest for the phone, driven by an alerting lifecycle rather than
  # a clock: publish on a state transition, stay silent while the mess is
  # unchanged, and re-nudge once the last published mess has stood past
  # ROOKERY_DIGEST_REPEAT_DAYS. Repetition without delta is alarm fatigue: a
  # channel that says the same sentence every day gets muted, and a count
  # threshold alone would let a small mess rot below the line forever. A
  # clean board removes the signature, so a rematch of an old mess
  # publishes as a fresh transition. The ntfy-send helper carries the local
  # broker as primary; the digest is deliberately not an alert and never an
  # urgency, it rides the subscribed topic with an hourglass tag. Count
  # fields are read defensively so the digest keeps working across minor
  # Rookery count-shape growth.
  boardDigest =
    pkgs.writeShellScript "rookery-board-digest"
    (
      (import ../../../lib/ntfy-send.nix {inherit pkgs lib;} {
        primary = "${cfg.boardDigest.ntfyUrl}/${cfg.boardDigest.topic}";
      })
      + ''
        set -euo pipefail
        repeat_days() {
          v="''${ROOKERY_DIGEST_REPEAT_DAYS:-7}"
          if printf '%s' "$v" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$'; then
            printf '%s' "$v"
          else
            echo 7
          fi
        }
        signature() {
          ${pkgs.coreutils}/bin/printf 'stale=%s unpushed=%s conflict=%s waitold=%s' "$stale" "$unpushed" "$conflict" "$waitold"
        }
        repo=${lib.escapeShellArg defaults.paths.nixosConfig}
        # Same exit condition as the gc body: a host without the checkout
        # exits cleanly so the timer's unit stays green for vestigial hosts.
        [ -d "$repo" ] || exit 0
        cd "$repo"
        state=${lib.escapeShellArg digestStateFile}
        # The alerting path decides nothing from the classification cache: both
        # calls rescan, so a transition is judged on the state that is published.
        read -r total empty merged unpushed inflight conflict stale waitold < <(${rookery}/bin/rookery ls --counts --refresh)
        waitold=''${waitold:-0}
        if [ "$((stale + unpushed + conflict + waitold))" -eq 0 ]; then
          # A clean board removes the stored signature so the same mess
          # returning later publishes as a fresh transition rather than a
          # rerun of an old record.
          ${pkgs.coreutils}/bin/rm -f "$state"
          exit 0
        fi
        sig="$(signature)"
        if [ -f "$state" ]; then
          olds="$(${pkgs.gnused}/bin/sed -n '1p' "$state")"
          oldat="$(${pkgs.gnused}/bin/sed -n '2p' "$state")"
          if ! printf '%s' "$oldat" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$'; then oldat=0; fi
          now=$(${pkgs.coreutils}/bin/date +%s)
          if [ "$olds" = "$sig" ] && [ $(( (now - oldat) / 86400 )) -lt "$(repeat_days)" ]; then
            # Same mess, recently published: the silence is the feature.
            exit 0
          fi
        fi
        if ! board=$(${rookery}/bin/rookery ls --board --refresh 2>/dev/null); then
          board=$(${rookery}/bin/rookery ls)
        fi
        body="$(${pkgs.coreutils}/bin/printf 'stale %s unpushed %s conflict %s old waits %s\n\n%s' "$stale" "$unpushed" "$conflict" "$waitold" "$board")"
        ntfy_send "rookery board ($(${pkgs.coreutils}/bin/uname -n))" low hourglass "$body"
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$state")"
        ${pkgs.coreutils}/bin/printf '%s\n%s\n' "$sig" "$(${pkgs.coreutils}/bin/date +%s)" > "$state"
      ''
    );
in {
  options.tui.jujutsu = {
    # Board digest: the daily gc timer publishes the workspace board to the
    # alerting ntfy topic so a host the user spends days away from still
    # reports waiting, in-review and unclean workspaces. Off by default:
    # only hosts whose ntfy broker the phone subscribes to publish.
    boardDigest = {
      enable = lib.mkEnableOption "ntfy digest of unclean Rookery workspaces, published on state transitions";
      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:2586";
        description = "Base URL of the ntfy broker the digest publishes through (loopback of the self-hosted instance)";
      };
      topic = lib.mkOption {
        type = lib.types.str;
        default = "homelab-alerts";
        description = "ntfy topic that receives the digest; the phone already subscribes to this channel, tagged so the message reads as a digest, not an alert";
      };
    };
  };

  imports = [
    ../shells/fish/functions/jj.nix
    inputs.rookery.homeManagerModules.default
  ];

  config = {
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

        # Live workspaces must not rewrite each other's history: a rebase in one
        # workspace that touches another workspace's ancestry resurrects a hidden
        # commit it still uses, and the two diverge. jj's stock immutability
        # covers trunk and tags only, so the guard is expressed where jj enforces
        # it. The custom term is workspace-relative: outside `default` every
        # other working-copy commit and its ancestors are immutable; in `default`
        # it collapses to none(), which keeps feature-stack integration working
        # there. `only_if` is an idiom, not a conditional: a nonempty condition
        # reaches root(), whose descendants are all(), while an empty one yields
        # none(). Verified against jj-sensei's boundaries policy.
        revset-aliases = {
          "other_workspaces()" = "working_copies() ~ @";
          "not_default()" = "@ ~ default@";
          "only_if(condition, revisions)" = "revisions & descendants(ancestors(condition))";
          "immutable_heads()" = "builtin_immutable_heads() | only_if(not_default(), other_workspaces())";
        };
      };
    };

    # The project module installs the configured binary and documents the
    # ROOKERY_* contract. Its own gc timer stays off: this module owns ocws-gc
    # below because the unit also writes the prompt badge and runs the digest.
    programs.rookery = {
      enable = true;
      base = "${config.home.homeDirectory}/.local/share/ocws";
      # Historical fleet prefix: existing workspaces live at
      # <base>/nixos-ws-<task> and must not be migrated.
      workspacePrefix = "nixos-ws-";
      trunk = "main@origin";
      gc.enable = false;
      tui.enable = true;
    };

    # Reclaim finished jj workspaces daily and refresh the prompt badge. The
    # classification is jj against main@origin, so the job runs from the primary
    # checkout and no-ops on a host that lacks it. `rookery gc` fetches, keeps
    # unpushed/in-flight/conflicted workspaces, any workspace with a live
    # process and any parked one, and reclaims empty/merged ones past the age
    # gate. The explicit cleanup marks from /workspace-done are swept
    # afterwards, with the same safety checks.
    systemd.user.services.ocws-gc = {
      Unit.Description = "Reclaim finished jj workspaces, sweep cleanup marks, and refresh the Rookery status badge";
      Service = {
        Type = "oneshot";
        ExecStart = toString (pkgs.writeShellScript "ocws-gc" ''
          set -euo pipefail
          repo=${lib.escapeShellArg defaults.paths.nixosConfig}
          badge=${lib.escapeShellArg badgeFile}
          [ -d "$repo" ] || exit 0
          cd "$repo"
          ${rookery}/bin/rookery gc
          # The explicit cleanup marks are swept after gc's fetch, so absorption
          # is judged against current origin. A skip keeps the workspace and is
          # reported in the unit log.
          ${rookery}/bin/rookery clean --apply
          # `gc` removes the stale directories; the reaper prunes child
          # subagent transcripts and keeps every top-level conversation.
          ${rookery}/bin/rookery reap
          read -r total empty merged unpushed inflight conflict stale waitold < <(${rookery}/bin/rookery ls --counts)
          waitold=''${waitold:-0}
          attention=$((unpushed + conflict))
          out=""
          if [ "$stale" -gt 0 ]; then out="🧹$stale "; fi
          if [ "$attention" -gt 0 ]; then out="$out⇡$attention "; fi
          # Only stale waits reach the badge: a fresh park is deliberate
          # deferral, a week-old wait is a forgotten promise and belongs in the
          # same category as other unclean state.
          if [ "$waitold" -gt 0 ]; then out="$out⏳$waitold "; fi
          mkdir -p "$(dirname "$badge")"
          printf '%s' "$out" > "$badge"
        '');
        # The digest runs as its own step so a broken publish cannot abort the
        # reclamation pass. Its own count parse reads past the last field that
        # Rookery today emits, so the digest keeps working when the count shape
        # grows. Silent by design on a clean board.
        ExecStartPost = lib.mkIf cfg.boardDigest.enable (toString boardDigest);
      };
    };
    systemd.user.timers.ocws-gc = {
      Install.WantedBy = ["timers.target"];
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # The board one key away from every herdr pane: same contributed key
    # pattern the tuicr and TTT modules use, same popup shape. The board links
    # rookery-core in process, and its configured wrapper supplies the fleet
    # base, prefix and trunk. `rookery ls --board` remains the CLI fallback.
    # The popup runs from the primary checkout so jj and the task store resolve
    # the fleet repository.
    tui.herdr.commandKeys = lib.mkAfter [
      {
        key = "prefix+shift+b";
        type = "popup";
        command = "cd ${lib.escapeShellArg defaults.paths.nixosConfig} && ${rookeryTui}/bin/rookery-tui";
        description = "Show the Rookery board";
        width = "95%";
        height = "95%";
      }

      # New agent seat one key away. A herdr tab inherits the focused pane's
      # worktree, so a bare tab plus opencode would share that working copy;
      # `rookery herdr` creates the tab and runs Rookery inside it. The binding runs
      # detached because the seat names itself: a filler task at creation,
      # `rookery title` once OpenCode has a session title. Failures (no herdr
      # binary, a live process in the workspace) land in the seat log rather
      # than a popup nobody is looking at.
      # prefix+shift+a is free (the defaults use r/n/g/w/d/t/x/p).
      {
        key = "prefix+shift+a";
        type = "shell";
        command = "${rookery}/bin/rookery herdr";
        description = "New agent seat: jj workspace + opencode in a new tab";
      }
    ];
  };
}
