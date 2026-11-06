{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) personalInfo defaults;

  cfg = config.tui.jujutsu;

  ocws = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ocws;
  herdrBoard = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr-board;
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
  # OCWS_DIGEST_REPEAT_DAYS. Repetition without delta is alarm fatigue: a
  # channel that says the same sentence every day gets muted, and a count
  # threshold alone would let a small mess rot below the line forever. A
  # clean board removes the signature, so a rematch of an old mess
  # publishes as a fresh transition. The ntfy-send helper carries the local
  # broker as primary; the digest is deliberately not an alert and never an
  # urgency, it rides the subscribed topic with an hourglass tag. Count
  # fields are read defensively so the digest keeps working across minor
  # ocws count-shape growth.
  boardDigest =
    pkgs.writeShellScript "ocws-board-digest"
    (
      (import ../../../lib/ntfy-send.nix {inherit pkgs lib;} {
        primary = "${cfg.boardDigest.ntfyUrl}/${cfg.boardDigest.topic}";
      })
      + ''
        set -euo pipefail
        repeat_days() {
          v="''${OCWS_DIGEST_REPEAT_DAYS:-7}"
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
        read -r total empty merged unpushed inflight conflict stale waitold < <(${ocws}/bin/ocws ls --counts)
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
        if ! board=$(${ocws}/bin/ocws ls --board 2>/dev/null); then
          board=$(${ocws}/bin/ocws ls)
        fi
        body="$(${pkgs.coreutils}/bin/printf 'stale %s unpushed %s conflict %s old waits %s\n\n%s' "$stale" "$unpushed" "$conflict" "$waitold" "$board")"
        ntfy_send "ocws board ($(${pkgs.coreutils}/bin/uname -n))" low hourglass "$body"
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
      enable = lib.mkEnableOption "ntfy digest of unclean ocws workspaces, published on state transitions";
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
      };
    };

    # Reclaim finished jj workspaces daily and refresh the prompt badge. The
    # classification is jj against main@origin, so the job runs from the primary
    # checkout and no-ops on a host that lacks it. `ocws gc` fetches, keeps
    # unpushed/in-flight/conflicted workspaces, any workspace with a live
    # process and any parked one, and reclaims empty/merged ones past the age
    # gate.
    systemd.user.services.ocws-gc = {
      Unit.Description = "Reclaim finished jj workspaces and refresh the ocws status badge";
      Service = {
        Type = "oneshot";
        ExecStart = toString (pkgs.writeShellScript "ocws-gc" ''
          set -euo pipefail
          # ocws's herdr-board card cleanup resolves board and herdr from PATH,
          # which a bare user unit does not carry; extend it only while the
          # board module is enabled (herdr ships fleet-wide, the packaged
          # board comes from the flake).
          ${lib.optionalString config.tui.herdrBoard.enable "PATH=${herdrBoard}/bin:${pkgs.herdr}/bin:$PATH"}
          repo=${lib.escapeShellArg defaults.paths.nixosConfig}
          badge=${lib.escapeShellArg badgeFile}
          [ -d "$repo" ] || exit 0
          cd "$repo"
          ${ocws}/bin/ocws gc
          read -r total empty merged unpushed inflight conflict stale waitold < <(${ocws}/bin/ocws ls --counts)
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
        # ocws today emits, so the digest keeps working when the count shape
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

    # The workspace board one key away from every herdr pane: same contributed
    # key pattern the tuicr and TTT modules use, same popup shape. The --board
    # flag degrades to the plain table when the installed ocws predates it, so
    # the key never dies on a host whose home profile is ahead of or behind the
    # package. fish runs panes (herdr detects it from SHELL), so the chain uses
    # fish's && and ||.
    tui.herdr.commandKeys = lib.mkAfter [
      {
        key = "prefix+shift+b";
        type = "popup";
        command = "cd ${lib.escapeShellArg defaults.paths.nixosConfig} && ocws ls --board 2>/dev/null || ocws ls";
        description = "Show the ocws workspace board";
        width = "95%";
        height = "95%";
      }
    ];
  };
}
