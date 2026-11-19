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

  # Detector bundle: exactly the two files the post-deploy detector needs.
  # detect-downgrades.sh sources its sibling lib-downgrade-compare.sh at
  # runtime via BASH_SOURCE, so both must land in the store together — but the
  # whole scripts directory would ship unrelated tooling into every closure.
  #
  # Deploy-time closure metrics are not emitted here: the monitoring module
  # emits them from a system activation script, which also covers the
  # interactive `nh os switch` and `switch-to-configuration test` paths.
  detectorBundle = pkgs.runCommand "comin-downgrade-detector" {} ''
    mkdir -p $out
    cp ${../../tools/scripts/detect-downgrades.sh} $out/detect-downgrades.sh
    cp ${../../tools/scripts/lib-downgrade-compare.sh} $out/lib-downgrade-compare.sh
  '';

  # Wrapper bridges comin's postDeploymentCommand hook (absolute path, no
  # arguments) to the repo detector script and its ntfy configuration.
  postDeploy = pkgs.writeShellApplication {
    name = "comin-post-deployment";
    runtimeInputs = with pkgs; [coreutils curl nix];
    text = ''
      export COMIN_NTFY_URL=${lib.escapeShellArg (toString cfg.alertNtfyUrl)}
      ${lib.optionalString cfg.persistSwitch ''
        # comin moves its own profile and switch-to-configuration updates the
        # running system only, so a deployment reaches the boot source only on
        # hosts whose bootloader reads that profile. Mirror it onto the NixOS
        # system profile for hosts that boot that profile directly. A `test`
        # deployment leaves the comin profile on the previous target, which is
        # how the two operations are told apart here.
        comin_target="$(readlink -f /nix/var/nix/profiles/system-profiles/comin 2>/dev/null || true)"
        running="$(readlink -f /run/current-system)"
        if [ -n "$comin_target" ] && [ "$comin_target" = "$running" ]; then
          nix-env --profile /nix/var/nix/profiles/system --set "$running"
        fi
      ''}
      exec ${pkgs.bash}/bin/bash ${detectorBundle}/detect-downgrades.sh
    '';
  };

  # comin 0.14.0 can wedge when a commit arrives during an evaluation or
  # build (upstream nlewo/comin#224): the previous generation is canceled and
  # the new commit is never scheduled. The exporter's last_* failure gauges
  # stay 0 in that state, so this timer reads `comin status`, pages, and
  # restarts the daemon. Explicit failure gauges are alerted in monitoring.nix.
  healthCheck = pkgs.writeShellApplication {
    name = "comin-health";
    runtimeInputs = [
      config.services.comin.package
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      host=${lib.escapeShellArg config.networking.hostName}
      state_dir=/var/lib/comin
      repo="$state_dir/repository"
      health_dir="$state_dir/health"
      metrics_dir=/var/lib/node-exporter/textfile
      notify_url=${lib.escapeShellArg (
        if cfg.alertNtfyUrl == null
        then ""
        else cfg.alertNtfyUrl
      )}
      now=$(date +%s)
      restarts=$(cat "$health_dir/restarts" 2>/dev/null || echo 0)
      alerted_at=$(cat "$health_dir/alerted-at" 2>/dev/null || echo 0)
      restarted_at=$(cat "$health_dir/restarted-at" 2>/dev/null || echo 0)
      stuck=0
      reason="none"
      detail=""

      install -d -m 0750 "$health_dir"

      status_ok=1
      status="$(comin status 2>&1)" || status_ok=0

      if [ "$status_ok" = 0 ]; then
        stuck=1
        reason="status-unavailable"
        detail="comin status failed: ''${status//$'\n'/ }"
      else
        builder="$(printf '%s\n' "$status" | sed -n '/^  Builder$/,/^  Deployer$/p')"
        deployer="$(printf '%s\n' "$status" | sed -n '/^  Deployer$/,$p')"
        builder_uuid="$(printf '%s\n' "$builder" | sed -n 's/^    Generation UUID //p' | head -n1)"
        builder_commit="$(printf '%s\n' "$builder" | sed -n 's/^    Commit ID //p' | head -n1 | awk '{print $1}')"
        deployer_commit="$(printf '%s\n' "$deployer" | sed -n 's/^    Commit ID //p' | head -n1 | awk '{print $1}')"
        deployer_op="$(printf '%s\n' "$deployer" | sed -n 's/^    Operation //p' | head -n1)"

        if printf '%s\n' "$builder" | grep -q 'Build canceled'; then
          stuck=1
          reason="build-canceled"
          detail="generation $builder_uuid for $builder_commit was canceled without a replacement"
        elif printf '%s\n' "$builder" | grep -qE 'Evaluation failed|Build failed'; then
          stuck=1
          reason="build-failed"
          detail="evaluation or build failed for $builder_commit"
        elif printf '%s\n' "$deployer" | grep -q 'Deployment failed'; then
          stuck=1
          reason="deploy-failed"
          detail="deployment failed for $deployer_commit"
        elif printf '%s\n' "$builder" | grep -qE 'Evaluation started|Build started'; then
          if [ "$(cat "$health_dir/active-uuid" 2>/dev/null || true)" != "$builder_uuid" ]; then
            printf '%s' "$builder_uuid" > "$health_dir/active-uuid"
            printf '%s' "$now" > "$health_dir/active-since"
          else
            active_since=$(cat "$health_dir/active-since" 2>/dev/null || echo "$now")
            if [ $((now - active_since)) -gt 9000 ]; then
              stuck=1
              reason="build-stuck"
              detail="generation $builder_uuid has been evaluating/building for more than 2.5 hours"
            fi
          fi
        else
          rm -f "$health_dir/active-uuid" "$health_dir/active-since"
        fi

        if [ "$stuck" = 0 ] && printf '%s\n' "$deployer" | grep -q 'Deployment is running'; then
          deploy_uuid="$(printf '%s\n' "$deployer" | sed -n 's/^    Generation //p' | head -n1)"
          if [ "$(cat "$health_dir/deploy-uuid" 2>/dev/null || true)" != "$deploy_uuid" ]; then
            printf '%s' "$deploy_uuid" > "$health_dir/deploy-uuid"
            printf '%s' "$now" > "$health_dir/deploy-since"
          else
            deploy_since=$(cat "$health_dir/deploy-since" 2>/dev/null || echo "$now")
            if [ $((now - deploy_since)) -gt 1800 ]; then
              stuck=1
              reason="deploy-stuck"
              detail="deployment $deploy_uuid has been running for more than 30 minutes"
            fi
          fi
        elif [ "$stuck" = 0 ]; then
          rm -f "$health_dir/deploy-uuid" "$health_dir/deploy-since"
        fi

        if [ "$stuck" = 0 ] && [ "$deployer_op" != "test" ]; then
          origin_main="$(git -C "$repo" rev-parse --verify refs/remotes/origin/main 2>/dev/null || true)"
          if [ -n "$origin_main" ] && [ "$origin_main" != "$deployer_commit" ] && [ "$origin_main" != "$builder_commit" ]; then
            if [ ! -f "$health_dir/origin-ahead-since" ]; then
              printf '%s' "$now" > "$health_dir/origin-ahead-since"
            fi
            ahead_since=$(cat "$health_dir/origin-ahead-since" 2>/dev/null || echo "$now")
            if [ $((now - ahead_since)) -gt 1800 ]; then
              stuck=1
              reason="origin-ahead"
              detail="origin/main $(printf '%.8s' "$origin_main") has not been deployed for more than 30 minutes"
            fi
          else
            rm -f "$health_dir/origin-ahead-since"
          fi
        elif [ "$stuck" = 0 ]; then
          rm -f "$health_dir/origin-ahead-since"
        fi
      fi

      if [ "$stuck" = 1 ] && [ $((now - alerted_at)) -ge 1800 ]; then
        message="comin is stuck on $host: $detail."
        if [ $((now - restarted_at)) -ge 1800 ]; then
          message="$message Restarting comin."
        else
          message="$message A restart was already attempted within 30 minutes."
        fi
        printf '%s\n' "$message" >&2
        if [ -n "$notify_url" ]; then
          curl -fsS --max-time 5 -o /dev/null \
            -H "Title: comin stuck on $host" \
            -H "Priority: high" \
            -H "Tags: rotating_light" \
            --data "$message" "$notify_url" || printf 'comin-health: ntfy notification failed\n' >&2
        fi
        printf '%s' "$now" > "$health_dir/alerted-at"
        if [ $((now - restarted_at)) -ge 1800 ]; then
          systemctl restart comin || printf 'comin-health: restart failed\n' >&2
          printf '%s' "$now" > "$health_dir/restarted-at"
          restarts=$((restarts + 1))
          printf '%s' "$restarts" > "$health_dir/restarts"
        fi
      fi

      if [ -d "$metrics_dir" ]; then
        metric_tmp="$(mktemp "$metrics_dir/.comin-health.XXXXXX")"
        {
          printf '# HELP comin_health_stuck Whether the comin healthcheck sees a wedged deployment.\n'
          printf '# TYPE comin_health_stuck gauge\n'
          printf 'comin_health_stuck{reason="%s"} %s\n' "$reason" "$stuck"
          printf '# HELP comin_health_last_check_timestamp_seconds Last comin healthcheck run.\n'
          printf '# TYPE comin_health_last_check_timestamp_seconds gauge\n'
          printf 'comin_health_last_check_timestamp_seconds %s\n' "$now"
          printf '# HELP comin_health_restarts_total comin restarts performed by the healthcheck.\n'
          printf '# TYPE comin_health_restarts_total counter\n'
          printf 'comin_health_restarts_total %s\n' "$restarts"
        } > "$metric_tmp"
        chmod 0644 "$metric_tmp"
        mv "$metric_tmp" "$metrics_dir/comin-health.prom"
      fi
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
        ntfy URL receiving comin deployment and health alerts plus package
        downgrade alerts after automated deployments. Unset logs detections to
        the journal instead.
      '';
    };

    persistSwitch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mirror a successful switch deployment onto the NixOS system profile.

        comin activates a deployment by writing system-profiles/comin and
        running switch-to-configuration, which updates the running system
        only. Hosts that boot through a bootloader pick the deployment up
        from that profile's boot entry; a WSL distribution boots
        /nix/var/nix/profiles/system directly, so without this a deployment
        is reverted at the next start.
      '';
    };

    localRemote = {
      enable = lib.mkEnableOption ''
        local polling remote for fast iteration on a development host.
        comin fetches the colocated checkout directly and applies its
        testing-<hostname> branch with switch-to-configuration test -
        without touching the bootloader and without a GitHub round trip.
        The checkout is user-writable, so any process that can move the
        testing bookmark can cause comin to build and activate code.
      '';

      path = lib.mkOption {
        type = lib.types.path;
        default = "/per/etc/nixos";
        description = "Colocated checkout polled for the testing branch";
      };

      pollPeriod = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Seconds between fetches of the local checkout";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.comin = {
        enable = true;
        # Upstream default is 1800s and applies to the whole build, not per
        # derivation: a single derivation larger than the timeout gets killed
        # and restarted from scratch every poll, wedging convergence forever
        # (FreeCAD-sized builds need hours).
        buildTimeout = 7200;
        remotes =
          [
            {
              name = "origin";
              url = cfg.remoteUrl;
              poller.period = cfg.pollPeriod;
              branches = {
                # main is the durable channel: always switched.
                main = {
                  name = "main";
                  operation = "switch";
                };
                # Testing is served by the local remote only. Disabling it
                # here keeps a stray GitHub testing branch from being selected.
                testing.name = "";
              };
            }
          ]
          ++ lib.optional cfg.localRemote.enable {
            name = "local";
            url = toString cfg.localRemote.path;
            poller.period = cfg.localRemote.pollPeriod;
            branches = {
              # No main on the local remote: origin/main stays the single
              # source of truth. `jjtest` sets testing-<hostname> on top of it.
              main.name = "";
              testing = {
                name = "testing-${config.networking.hostName}";
                operation = "test";
              };
            };
          };
        postDeploymentCommand = lib.getExe postDeploy;
      };

      # A crash should stop after a bounded budget so the ServiceFailed alert
      # sees a failed unit; a wedged-but-active daemon is the healthcheck's job.
      systemd.services.comin = {
        serviceConfig.RestartSec = "10s";
        unitConfig.StartLimitBurst = 60;
        unitConfig.StartLimitIntervalSec = 900;
      };

      systemd.services.comin-health = {
        description = "Detect and recover a wedged comin deployment";
        after = ["comin.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe healthCheck;
        };
      };

      systemd.timers.comin-health = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "10min";
          OnActiveSec = "1min";
          OnUnitActiveSec = "5min";
          AccuracySec = "30s";
        };
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
  ];
}
