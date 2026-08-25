# Scheduled maintenance orchestration for health checks, cleanup, and alerting.
# Centralizes recurring host hygiene tasks under one opt-in module.
# Lock updates are intentionally not automated per host: they flow through
# the reviewed daily-updates CI PR, and comin converges hosts to main; the
# optional lock-refresh watchdog observes that CI from a trusted host.
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.maintenance = {
    enable = lib.mkEnableOption "automated system maintenance";

    monitoring = {
      enable = lib.mkEnableOption "system health monitoring";
      alerts = lib.mkEnableOption "health alert notifications";
      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:2586/homelab-alerts";
        description = "ntfy URL for health alert notifications";
      };
    };

    # Deferred restarts of network daemons during a nightly window. Hosts set
    # systemd.services.*.restartIfChanged = false for the daemons listed here,
    # so a daytime switch never drops the link; the restarts (and thus the
    # freshly updated binaries/configs) are applied once at night instead.
    deferredRestarts = {
      enable = lib.mkEnableOption "deferred network daemon restarts in a nightly window";
      services = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to restart in the nightly window instead of on every switch";
      };
      time = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:00:00";
        description = "OnCalendar schedule for the nightly maintenance window";
      };
      autoRebootForKernel = lib.mkEnableOption "auto-reboot in the window when a kernel update is pending";
      networkSanity = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            interface = lib.mkOption {
              type = lib.types.str;
              description = "Interface to verify after a networkd restart (e.g. eno1)";
            };
            address = lib.mkOption {
              type = lib.types.str;
              description = "Expected static address on the interface (e.g. 192.168.178.2/24)";
            };
            gateway = lib.mkOption {
              type = lib.types.str;
              description = "Gateway to ping after the networkd restart";
            };
            networkFile = lib.mkOption {
              type = lib.types.str;
              default = "/etc/systemd/network/10-eno1.network";
              description = "Networkd config file that must keep the static address/gateway";
            };
          };
        });
        default = null;
        description = "Sanity-gate parameters guarding the networkd restart";
      };
    };

    # Daily check that the lock-refresh CI (single flake.lock writer) actually
    # succeeded. GitHub runners cannot reach a LAN ntfy, so workflow-side
    # failure() steps cannot alert; this local watchdog closes that gap - the
    # Aug 2026 cron failures stayed unnoticed for two days without it.
    lockRefreshWatch = {
      enable = lib.mkEnableOption "daily watchdog for the lock-refresh CI workflow";
      repository = lib.mkOption {
        type = lib.types.str;
        default = "FelixSchausberger/nixos";
        description = "GitHub repository whose lock-refresh workflow is watched";
      };
      workflow = lib.mkOption {
        type = lib.types.str;
        default = "daily-updates.yml";
        description = "Workflow file checked for failures and staleness";
      };
    };
  };

  config = lib.mkIf config.modules.system.maintenance.enable {
    modules.system.securityHardening.enable = lib.mkDefault true;

    systemd = {
      services = {
        # Generic host-level health checks. Works on any NixOS host without
        # Prometheus. Grafana-provisioned alert rules (modules/system/homelab/
        # monitoring.nix) extend this with homelab-specific service
        # monitoring (Nextcloud, Immich, AdGuard, Postgres, Node exporter) via
        # Prometheus queries with grouping and resolve notifications.
        system-health-check = lib.mkIf config.modules.system.maintenance.monitoring.enable {
          description = "System health monitoring";
          script = ''
            set -eu

            # Service PATH lacks hostname(1) (nettools), so resolve the host
            # up front; alert titles must always identify the source host.
            host=$(${pkgs.nettools}/bin/hostname)

            ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              NTFY_URL="${config.modules.system.maintenance.monitoring.ntfyUrl}"
              ntfy_send() {
                ${pkgs.curl}/bin/curl -s -o /dev/null \
                  -H "Title: $1" \
                  -H "Priority: $2" \
                  -H "Tags: $3" \
                  -d "$4" \
                  "$NTFY_URL" 2>/dev/null || true
              }
            ''}

            # Check for failed services
            failed_services=$(${pkgs.systemd}/bin/systemctl --failed --no-legend | wc -l)
            if [[ $failed_services -gt 0 ]]; then
              failed_detail=$(${pkgs.systemd}/bin/systemctl --failed --no-legend)
              echo "WARNING: $failed_services failed services detected"
              echo "$failed_detail"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "Failed Services on $host" "high" "warning" "$failed_detail"
            ''}
            fi

            # A loaded timer with no next elapse never fires again. Automated
            # deploys have left timers in this disarmed state while still
            # reporting active, silently dropping nightly maintenance windows.
            # Calendar-scheduled timers set NextElapseUSecRealtime,
            # monotonic-scheduled ones NextElapseUSecMonotonic; a disarmed
            # timer reports infinity/empty for both.
            #
            # systemd 261 defers rearming until the triggered service exits,
            # so both properties ALSO read empty between a timer elapsing and
            # its service finishing; those timers are healthy and skipped.
            # This check runs on the hour, the same second several hourly
            # timers fire.
            for unit in $(${pkgs.systemd}/bin/systemctl list-unit-files --type=timer --state=enabled --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
              rt_elapse=$(${pkgs.systemd}/bin/systemctl show "$unit" --property=NextElapseUSecRealtime --value)
              mono_elapse=$(${pkgs.systemd}/bin/systemctl show "$unit" --property=NextElapseUSecMonotonic --value)
              if [[ -z "$rt_elapse" && ( -z "$mono_elapse" || "$mono_elapse" == "infinity" ) ]]; then
                # Skip only while the triggered service is busy: oneshot
                # starts read SubState "start", Type=simple runs read
                # "running". A finished RemainAfterExit service settles at
                # "exited" and must NOT be skipped - that is exactly the
                # network-maintenance disarm case.
                svc_sub=$(${pkgs.systemd}/bin/systemctl show "''${unit%.timer}.service" --property=SubState --value)
                if [[ "$svc_sub" != "dead" && "$svc_sub" != "exited" && "$svc_sub" != "failed" ]]; then
                  continue
                fi
                echo "WARNING: timer $unit has no next elapse; attempting rearm"
                # A plain restart does not clear this corrupted state
                # (observed on systemd 261: still unarmed minutes later), and
                # starting a persistent timer with its stamp intact replays
                # the missed elapse immediately - an unwanted midday reboot
                # for the nightly window. Purging the stamp rearms cleanly
                # and waits for the next scheduled slot instead.
                ${pkgs.systemd}/bin/systemctl stop "$unit" || true
                rm -f "/var/lib/systemd/timers/stamp-$unit"
                rearmed=0
                if ${pkgs.systemd}/bin/systemctl start "$unit"; then
                  rt_after=$(${pkgs.systemd}/bin/systemctl show "$unit" --property=NextElapseUSecRealtime --value)
                  mono_after=$(${pkgs.systemd}/bin/systemctl show "$unit" --property=NextElapseUSecMonotonic --value)
                  if [[ -n "$rt_after" || ( -n "$mono_after" && "$mono_after" != "infinity" ) ]]; then
                    rearmed=1
                  fi
                fi
                ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              if [[ $rearmed -eq 1 ]]; then
                ntfy_send "Timer Rearmed on $host" "default" "warning" "$unit reported active but had no scheduled elapse; purged stamp and rearmed automatically"
              else
                ntfy_send "Timer Disarmed on $host" "high" "warning" "$unit has no scheduled elapse and automatic rearm failed. Run: sudo systemctl restart $unit"
              fi
            ''}
                if [[ $rearmed -eq 0 ]]; then
                  echo "ERROR: timer $unit could not be rearmed automatically"
                fi
              fi
            done

            # Check disk space
            root_usage=$(df / | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $root_usage -gt 90 ]]; then
              echo "WARNING: Root filesystem is $root_usage% full"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High Disk Usage on $host" "high" "warning" "Root filesystem is $root_usage% full"
            ''}
            fi

            nix_usage=$(df /nix | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $nix_usage -gt 85 ]]; then
              echo "WARNING: Nix store is $nix_usage% full"
              echo "Consider running: clean"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High Nix Store Usage on $host" "high" "warning" "Nix store is $nix_usage% full"
            ''}
            fi

            # Check for old generations
            generation_count=$(${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l)
            if [[ $generation_count -gt 10 ]]; then
              echo "INFO: $generation_count system generations present (consider cleanup)"
            fi

            # Check memory usage
            mem_usage=$(${pkgs.procps}/bin/free | grep Mem | ${pkgs.gawk}/bin/awk '{printf "%.0f", $3/$2 * 100.0}')
            if [[ $mem_usage -gt 90 ]]; then
              echo "WARNING: Memory usage is $mem_usage%"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High Memory Usage on $host" "high" "warning" "Memory usage is $mem_usage%"
            ''}
            fi

            # CPU package temperature: >=90 C indicates cooling failure (fan or
            # dust). Hardware still throttles at Tjmax (~100 C), so this is an
            # early warning below the kernel's "high" mark. Only x86_pkg_temp
            # exists on Intel hosts; other platforms are silently skipped.
            pkg_temp=0
            for zone in /sys/class/thermal/thermal_zone*; do
              if [[ "$(<"$zone/type")" == x86_pkg_temp ]]; then
                t=$(<"$zone/temp")
                if [[ $t -gt $pkg_temp ]]; then pkg_temp=$t; fi
              fi
            done
            if [[ $pkg_temp -ge 90000 ]]; then
              echo "WARNING: CPU package temperature is $((pkg_temp / 1000)) C"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High CPU Temperature on $host" "urgent" "warning" "CPU package at $((pkg_temp / 1000)) C, check cooling"
            ''}
            fi

            # Kernel update pending (deployed but not booted): reboot required. On
            # hosts with autoRebootForKernel the nightly window handles the reboot.
            if [[ "$(readlink -f /run/current-system/kernel 2>/dev/null)" != "$(readlink -f /run/booted-system/kernel 2>/dev/null)" ]]; then
              echo "WARNING: kernel update deployed but not booted (reboot pending)"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              if [[ ! -f /run/reboot-pending-notified ]]; then
                : > /run/reboot-pending-notified
                ntfy_send "Reboot Pending on $host" "default" "warning" "Kernel update deployed but not booted. Run: sudo reboot"
              fi
            ''}
            fi

            # ZFS health check (if ZFS is available)
            if command -v zpool >/dev/null 2>&1; then
              zpool_status=$(zpool status -x)
              if [[ "$zpool_status" != "all pools are healthy" ]]; then
                echo "WARNING: ZFS pool health issues detected:"
                echo "$zpool_status"
                ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "ZFS Pool Issue on $host" "urgent" "warning" "$zpool_status"
            ''}
              fi
            fi

            echo "Health check completed at $(date)"
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
          };
        };

        nixos-cleanup = {
          description = "Automated NixOS cleanup";
          script = ''
            set -eu

            echo "Starting automated cleanup..."

            # Clean old generations (keep last 5)
            ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +5

            # Garbage collect with automatic confirmation
            ${pkgs.nix}/bin/nix store gc

            # Optimize store
            ${pkgs.nix}/bin/nix store optimise

            # Clean temporary files while ignoring ephemeral roots that may not be
            # attached in impermanence configurations.
            ${pkgs.systemd}/bin/systemd-tmpfiles --clean --exclude-prefix=/tmp --exclude-prefix=/var/tmp --exclude-prefix=/nix/var/nix --exclude-prefix=/var/lib/systemd

            echo "Cleanup completed at $(date)"
          '';
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
            Nice = 19;
            IOSchedulingClass = "idle";
            TimeoutStartSec = 600;
          };
        };

        # Nightly maintenance: apply deferred network daemon restarts and, when a
        # kernel update is pending, reboot. Runs at 04:00 so network restarts never
        # interrupt daytime use. The networkd restart is gated by a pre-check (the
        # static network file must still set the LAN IP/gateway) and a post-check
        # (address present + gateway reachable); on failure the config is rolled back
        # to the booted generation and the daemon restarted.
        network-maintenance = lib.mkIf config.modules.system.maintenance.deferredRestarts.enable {
          description = "Nightly network maintenance (deferred restarts and pending reboot)";
          after = ["multi-user.target"];
          wants = ["multi-user.target"];
          script = let
            list = config.modules.system.maintenance.deferredRestarts.services;
            sanity = config.modules.system.maintenance.deferredRestarts.networkSanity;
          in ''
            set -euo pipefail
            echo "=== maintenance window started at $(date) ==="

            rollback_network_config() {
              rm -rf /etc/systemd/network
              mkdir -p /etc/systemd/network
              cp -a /run/booted-system/etc/systemd/network/. /etc/systemd/network/
              ${pkgs.systemd}/bin/systemctl restart systemd-networkd || true
              ${pkgs.curl}/bin/curl -s -o /dev/null \
                -H "Title: network-maintenance rollback" -H "Priority: urgent" -H "Tags: warning,cd" \
                -d "network config rolled back to booted generation after failed networkd restart" \
                "${config.modules.system.maintenance.monitoring.ntfyUrl}" || true
            }

            list=(${lib.concatStringsSep " " list})
            networkd_ok=1

            if [[ " ''${list[*]} " == *" systemd-networkd "* ]]; then
              ${lib.optionalString (sanity != null) ''
              cfg="${sanity.networkFile}"
              if [[ ! -f "$cfg" ]] \
                || ! grep -qs "Address=${sanity.address}" "$cfg" \
                || ! grep -qs "Gateway=${sanity.gateway}" "$cfg"; then
                echo "ERROR: $cfg no longer sets ${sanity.address} via ${sanity.gateway}; skipping networkd restart" >&2
                ${pkgs.curl}/bin/curl -s -o /dev/null \
                  -H "Title: network-maintenance blocked" -H "Priority: urgent" -H "Tags: warning,cd" \
                  -d "networkd restart aborted: $cfg missing static IP/gateway" \
                  "${config.modules.system.maintenance.monitoring.ntfyUrl}" || true
                networkd_ok=0
              else
                if ${pkgs.systemd}/bin/systemctl restart systemd-networkd; then
                  ok=0
                  for _ in $(seq 1 40); do
                    if ${pkgs.iproute2}/bin/ip -4 addr show "${sanity.interface}" 2>/dev/null | grep -q "${sanity.address}" \
                      && ${pkgs.iputils}/bin/ping -c1 -W1 "${sanity.gateway}" >/dev/null 2>&1; then
                      ok=1
                      break
                    fi
                    sleep 1
                  done
                  if [[ $ok -eq 0 ]]; then
                    echo "WARN: networkd restarted but ${sanity.interface} did not regain ${sanity.address}; rolling back network config" >&2
                    rollback_network_config
                    networkd_ok=0
                  fi
                else
                  echo "WARN: systemd-networkd failed to restart; rolling back network config" >&2
                  rollback_network_config
                  networkd_ok=0
                fi
              fi
            ''}
              ${lib.optionalString (sanity == null) ''
              # No sanity-gate configured: restart blindly (pre-check skipped).
              ${pkgs.systemd}/bin/systemctl restart systemd-networkd || networkd_ok=0
            ''}
            fi

            # Deferred daemons other than networkd (resolved, tailscaled, ...).
            for s in "''${list[@]}"; do
              [[ "$s" == "systemd-networkd" ]] && continue
              ${pkgs.systemd}/bin/systemctl restart "$s" || echo "WARN: restart $s failed" >&2
            done

            ${lib.optionalString config.modules.system.maintenance.deferredRestarts.autoRebootForKernel ''
              # Apply a pending kernel update only if the network came back cleanly.
              if [[ "$networkd_ok" -eq 1 ]] \
                && [[ "$(readlink -f /run/current-system/kernel 2>/dev/null)" != "$(readlink -f /run/booted-system/kernel 2>/dev/null)" ]]; then
                # Flush the zellij session serialization tail (runs every 1 s) to
                # disk so the next attach can resurrect from a fresh snapshot.
                echo "flushing zellij session data before reboot"
                ${pkgs.coreutils}/bin/sync
                echo "kernel update pending; rebooting to apply"
                ${pkgs.systemd}/bin/systemctl reboot
              fi
            ''}

            echo "=== maintenance window finished at $(date) ==="
          '';
          serviceConfig = {
            Type = "oneshot";
            # No RemainAfterExit: an active-exited oneshot turns every later
            # timer fire into a no-op (observed 2026-08-21..25, nightly runs
            # silently skipped). Returning to inactive keeps each fire fresh.
            User = "root";
            Group = "root";
            TimeoutStartSec = 600;
          };
        };

        # Queries the last completed run of the lock-refresh workflow via the
        # unauthenticated GitHub API (the repository is public; one call per
        # day is far below the rate limit) and alerts when it failed or never
        # ran. Runs once daily at 06:30 local time: the 03:00 UTC cron plus
        # CI validation and auto-merge are reliably done by then.
        lock-refresh-watchdog = lib.mkIf config.modules.system.maintenance.lockRefreshWatch.enable {
          description = "Watchdog for the daily lock-refresh CI workflow";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          script = let
            cfgWatch = config.modules.system.maintenance.lockRefreshWatch;
            ntfyUrl = config.modules.system.maintenance.monitoring.ntfyUrl;
          in ''
            set -euo pipefail

            api="https://api.github.com/repos/${cfgWatch.repository}/actions/workflows/${cfgWatch.workflow}/runs?per_page=5"

            response=$(${pkgs.curl}/bin/curl -sf \
              -H "Accept: application/vnd.github+json" "$api") \
              || { echo "WARN: GitHub API unreachable; watchdog check skipped" >&2; exit 0; }

            run=$(printf '%s' "$response" | ${pkgs.jq}/bin/jq -r \
              '[.workflow_runs[] | select(.status == "completed")][0] // empty')
            if [[ -z "$run" ]]; then
              echo "ERROR: no completed ${cfgWatch.workflow} run found" >&2
              ${pkgs.curl}/bin/curl -s -o /dev/null \
                -H "Title: Lock refresh missing on ${cfgWatch.repository}" \
                -H "Priority: high" -H "Tags: warning,cd" \
                -d "No completed ${cfgWatch.workflow} run found; cron may be disabled" \
                "${ntfyUrl}" || true
              exit 0
            fi

            conclusion=$(printf '%s' "$run" | ${pkgs.jq}/bin/jq -r .conclusion)
            run_id=$(printf '%s' "$run" | ${pkgs.jq}/bin/jq -r .id)
            age_hours=$(( ($(date +%s) - $(printf '%s' "$run" | ${pkgs.jq}/bin/jq -r '.created_at | fromdateiso8601')) / 3600 ))

            if [[ "$conclusion" != "success" ]]; then
              echo "ERROR: lock-refresh run $run_id concluded '$conclusion'" >&2
              ${pkgs.curl}/bin/curl -s -o /dev/null \
                -H "Title: Lock refresh failed on ${cfgWatch.repository}" \
                -H "Priority: high" -H "Tags: warning,cd" \
                -d "Run $run_id concluded '$conclusion'; flake.lock is stale until fixed. Check: gh run view $run_id -R ${cfgWatch.repository} --log-failed" \
                "${ntfyUrl}" || true
            elif [[ "$age_hours" -gt 26 ]]; then
              echo "ERROR: last successful lock-refresh run is $age_hours h old" >&2
              ${pkgs.curl}/bin/curl -s -o /dev/null \
                -H "Title: Lock refresh stale on ${cfgWatch.repository}" \
                -H "Priority: high" -H "Tags: warning,cd" \
                -d "Last completed run ($run_id) is $age_hours hours old; cron did not fire" \
                "${ntfyUrl}" || true
            else
              echo "Lock refresh healthy: run $run_id succeeded $age_hours h ago"
            fi
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
            TimeoutStartSec = 120;
          };
        };
      };

      timers = {
        system-health-check = lib.mkIf config.modules.system.maintenance.monitoring.enable {
          description = "Timer for system health monitoring";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
          };
        };

        nixos-cleanup = {
          description = "Timer for automated NixOS cleanup";
          wantedBy = ["timers.target"];
          after = ["multi-user.target"];
          timerConfig = {
            OnCalendar = "weekly";
            # Non-persistent: skip missed runs instead of bursting at boot.
            # Cleanup is best-effort, so a missed week is safe.
            Persistent = false;
            RandomizedDelaySec = "2h";
          };
        };

        network-maintenance = lib.mkIf config.modules.system.maintenance.deferredRestarts.enable {
          description = "Timer for nightly network maintenance";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = config.modules.system.maintenance.deferredRestarts.time;
            Persistent = true;
            RandomizedDelaySec = "5min";
          };
        };

        lock-refresh-watchdog = lib.mkIf config.modules.system.maintenance.lockRefreshWatch.enable {
          description = "Timer for the daily lock-refresh CI watchdog";
          wantedBy = ["timers.target"];
          after = ["multi-user.target"];
          timerConfig = {
            # 06:30 local: the 03:00 UTC cron plus validation and auto-merge
            # have reliably finished by then.
            OnCalendar = "*-*-* 06:30:00";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
      };
    };

    # Log rotation improvements
    services.logrotate = {
      enable = true;
      settings = {
        header = {
          dateext = true;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          create = "0644 root root";
        };

        "/var/log/nixos/*" = {
          rotate = 7;
          daily = true;
          maxage = 30;
        };
      };
    };
  };
}
