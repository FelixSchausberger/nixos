# Pull-based GitOps deployment via comin.
#
# flake.lock has a single writer: the daily-updates GitHub Actions workflow
# (daily cron, on-demand through update-system.sh). Hosts poll the public
# GitHub main branch and deploy nixosConfigurations.<hostname> automatically;
# store paths mostly substitute from cachix, warmed by
# .github/workflows/cachix-push.yml after every merge.
#
# The interactive deploy path (nh.nix aliases) keeps guard-downgrades.sh as a
# blocking check. This automated path cannot block - a blocked host would go
# stale while unattended - so regressions are detected after deployment by
# detect-downgrades.sh and reported to ntfy. A bad lock is healed by
# reverting its commit on main, after which every host converges back.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.system.comin;

  user = inputs.self.lib.user;
  homeDir = "/home/${user}";

  # Wrapper bridges comin's postDeploymentCommand hook (absolute path, no
  # arguments) to the repo detector script and its ntfy configuration.
  postDeploy = pkgs.writeShellApplication {
    name = "comin-post-deployment";
    runtimeInputs = with pkgs; [coreutils curl nix];
    text = ''
      export COMIN_NTFY_URL=${lib.escapeShellArg (toString cfg.alertNtfyUrl)}
      exec ${pkgs.bash}/bin/bash ${../../tools/scripts/detect-downgrades.sh}
    '';
  };

  # Auto-push reconciler: turns locally committed (described) work into PRs
  # before comin's next poll can converge the deployed system over it.
  # Undescribed working-copy edits are never touched - comin cannot lose them
  # anyway (it deploys its own clone), they just never reach main until
  # described.
  autopush = pkgs.writeShellApplication {
    name = "comin-autopush";
    runtimeInputs = with pkgs; [jujutsu gh git curl coreutils gnugrep gnused];
    text = ''
      set -euo pipefail

      repo="${cfg.autoPush.repoPath}"
      cd "$repo"

      # Alert helper: ntfy with signature-based dedupe so the poll timer does
      # not spam while a failure persists; re-alerts on changed reason or
      # after 6 hours.
      alert() {
        echo "comin-autopush: $*" >&2
        if [ -n "''${COMIN_NTFY_URL:-}" ]; then
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/comin-autopush"
          mkdir -p "$state"
          now=$(date +%s)
          sig=$(printf '%s' "$*" | ${pkgs.coreutils}/bin/md5sum | cut -c1-16)
          last_sig=$(cat "$state/signature" 2>/dev/null || true)
          last_ts=$(cat "$state/timestamp" 2>/dev/null || echo 0)
          if [ "$sig" != "$last_sig" ] || [ $((now - last_ts)) -gt 21600 ]; then
            curl -fsS --max-time 10 \
              -H "Title: comin-autopush: unpushed work on $(hostname)" \
              -H "Tags: warning" \
              -d "$*" \
              "$COMIN_NTFY_URL" >/dev/null 2>&1 || true
            printf '%s' "$sig" >"$state/signature"
            printf '%s' "$now" >"$state/timestamp"
          fi
        fi
      }

      # Commits neither merged into origin main nor carried by a pushed
      # branch. Everything else is either deployed state or represented by
      # an open PR - both safe to leave alone.
      #
      # Implemented with git plumbing on the colocated repo rather than jj
      # revsets: `jj log '(main@origin..@) ~ (::heads(remote_bookmarks()))'`
      # evaluated inconsistently under non-interactive shells on jj 0.44
      # (empty result set despite matching revisions), while rev-list's
      # --not --remotes is deterministic and sees the same object graph.
      # The working-copy commit id comes from jj because git HEAD may lag
      # behind jj @ in colocated repos (detached by non-jj git usage);
      # range ends there (= jj @): jj snapshots edits into the
      # working-copy commit, so freshly described work typically sits IN @.
      todo() {
        local at
        at="$(jj log -r '@' --no-graph -T 'commit_id' 2>/dev/null)" || return 1
        [ -n "$at" ] || return 1
        git rev-list --count "origin/main..''${at}" --not --remotes=origin 2>/dev/null || echo 1
      }

      [ "$(todo)" -eq 0 ] && exit 0

      # Rebase onto latest main first (fetch + cleanup); conflicts need human
      # resolution and keep the work unpushed.
      if ! jjwork >/dev/null 2>&1; then
        alert "jjwork failed in $repo (conflict or diverged main) - local commits are NOT being deployed; resolve manually"
        exit 1
      fi

      [ "$(todo)" -eq 0 ] && exit 0

      # Undescribed working-copy edits are never pushed: fabricating a commit
      # message would auto-deploy half-done work once CI passes. Only an
      # EMPTY @ may borrow its parent's description.
      at_empty="$(jj log --no-graph -r '@' -T 'if(empty, "true", "false")' 2>/dev/null | tr -d '[:space:]')"
      first_line="$(jj log --no-graph -r '@' -T 'description.first_line()' 2>/dev/null)"
      if [ "$first_line" = "(no description set)" ]; then
        if [ "$at_empty" != "true" ]; then
          alert "undescribed working-copy edits in $repo will not be auto-pushed; run 'jj describe' to include them"
          exit 1
        fi
        first_line="$(jj log --no-graph -r '@-' -T 'description.first_line()' 2>/dev/null)"
      fi
      if [ -z "$first_line" ] || [ "$first_line" = "(no description set)" ]; then
        alert "undescribed WIP in $repo will not be auto-pushed; run 'jj describe' to include it"
        exit 1
      fi

      # Ensure a feature bookmark exists so jjpush takes its bookmarked path
      # (which folds an empty working copy into the commit). Sanitizer mirrors
      # modules/home/shells/fish/functions/jj.nix.
      bookmark="$(jj bookmark list -r 'ancestors(@, 5) & bookmarks() & ~bookmarks("main")' -T 'name' 2>/dev/null | head -1 | tr -d '[:space:]')"
      if [ -z "$bookmark" ]; then
        bookmark="$(printf '%s' "$first_line" | sed -E 's/^([a-z]+)\(([^)]*)\):/\1\/\2/; s/^([a-z]+):[[:space:]]*/\1\//; s/ /-/g; s/[^a-zA-Z0-9_\/-]//g')"
        jj bookmark set "$bookmark" >/dev/null
        echo "comin-autopush: created bookmark $bookmark"
      fi

      if ! jjpush >/dev/null 2>&1; then
        alert "jjpush failed in $repo - inspect with journalctl --user -u comin-autopush"
        exit 1
      fi

      echo "comin-autopush: pushed local work; CI decides deployment via auto-merge"
    '';
  };
in {
  imports = [inputs.comin.nixosModules.comin];

  options.modules.system.comin = {
    enable = lib.mkEnableOption "comin pull-based GitOps deployment";

    remoteUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/FelixSchausberger/nixos.git";
      description = "Git repository polled by comin for new main commits";
    };

    pollPeriod = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds between git fetches of the remote main branch";
    };

    alertNtfyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        ntfy URL receiving package downgrade alerts after automated
        deployments. Unset logs detections to the journal instead.
      '';
    };

    autoPush = {
      enable = lib.mkEnableOption ''
        auto-push reconciler for development hosts. Periodically turns
        described local commits into PRs (CI + auto-merge decide deployment),
        so comin's convergence to origin/main cannot silently revert recent
        local work. Undescribed working-copy edits are never pushed.
      '';

      repoPath = lib.mkOption {
        type = lib.types.path;
        default = "/per/etc/nixos";
        description = "Path of the jj colocated config repository to reconcile";
      };

      intervalSec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 600;
        description = "Seconds between reconciler runs";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.comin = {
        enable = true;
        remotes = [
          {
            name = "origin";
            url = cfg.remoteUrl;
            poller.period = cfg.pollPeriod;
          }
        ];
        postDeploymentCommand = lib.getExe postDeploy;
      };

      # Deployment history and the repository clone live here; losing them on
      # an impermanence system would re-deploy the same commit on every boot
      # and discard rollback state.
      environment.persistence."/per".directories = [
        {
          directory = "/var/lib/comin";
          user = "root";
          group = "root";
          mode = "0750";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.autoPush.enable) {
      # User-level units: jjpush needs the user's gh/git credentials, which are
      # only reachable from the user manager with a full HOME. Linger (set in
      # zellij-web.nix on m920q) keeps the timer alive while logged out.
      systemd.user.services.comin-autopush = {
        description = "Auto-push described local commits ahead of comin convergence";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe autopush;
          TimeoutStartSec = "30min";
          Environment = [
            "HOME=${homeDir}"
            "COMIN_NTFY_URL=${toString cfg.alertNtfyUrl}"
            "XDG_STATE_HOME=${homeDir}/.local/state"
            # Login-equivalent PATH: jjwork/jjpush and git credential helpers
            # live in the user profile.
            "PATH=/etc/profiles/per-user/${user}/bin:/run/wrappers/bin:${homeDir}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
          ];
        };
      };

      systemd.user.timers.comin-autopush = {
        description = "Periodic auto-push of local config work";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "${toString cfg.autoPush.intervalSec}s";
          RandomizedDelaySec = "45";
          Persistent = true;
        };
      };
    })
  ];
}
