# Scheduled maintenance orchestration for updates, health checks, and alerting.
# Centralizes recurring host hygiene tasks under one opt-in module.
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.maintenance = {
    enable = lib.mkEnableOption "automated system maintenance";

    autoUpdate = {
      enable = lib.mkEnableOption "automatic flake updates";
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "Update schedule (systemd timer format)";
      };
    };

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
  };

  config = lib.mkIf config.modules.system.maintenance.enable {
    modules.system.securityHardening.enable = lib.mkDefault true;

    systemd = {
      services = {
        nixos-auto-update = lib.mkIf config.modules.system.maintenance.autoUpdate.enable {
          description = "Automatic NixOS flake update";
          script = ''
              set -eu

              cd /per/etc/nixos

              # Check if there are uncommitted changes
              if [[ -n "$(${pkgs.git}/bin/git status --porcelain)" ]]; then
                echo "Uncommitted changes detected, skipping auto-update"
                exit 0
              fi

              # Update flake inputs
              ${pkgs.nix}/bin/nix flake update --commit-lock-file

            # Test build (don't switch automatically for safety)
            ${pkgs.nix}/bin/nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel --no-link

            echo "Flake updated successfully. Use 'deploy' to apply changes."
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
          };
        };

        # Generic host-level health checks. Works on any NixOS host without
        # Prometheus. homelab-alerter extends this with homelab-specific service
        # monitoring (Nextcloud, Immich, AdGuard, Postgres, Node exporter) via
        # Prometheus queries with cooldown and resolve notifications.
        system-health-check = lib.mkIf config.modules.system.maintenance.monitoring.enable {
          description = "System health monitoring";
          script = ''
            set -eu

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
              ntfy_send "Failed Services on $(hostname)" "high" "warning" "$failed_detail"
            ''}
            fi

            # Check disk space
            root_usage=$(df / | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $root_usage -gt 90 ]]; then
              echo "WARNING: Root filesystem is $root_usage% full"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High Disk Usage on $(hostname)" "high" "warning" "Root filesystem is $root_usage% full"
            ''}
            fi

            nix_usage=$(df /nix | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $nix_usage -gt 85 ]]; then
              echo "WARNING: Nix store is $nix_usage% full"
              echo "Consider running: clean"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              ntfy_send "High Nix Store Usage on $(hostname)" "high" "warning" "Nix store is $nix_usage% full"
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
              ntfy_send "High Memory Usage on $(hostname)" "high" "warning" "Memory usage is $mem_usage%"
            ''}
            fi

            # Kernel update pending (deployed but not booted): reboot required. On
            # hosts with autoRebootForKernel the nightly window handles the reboot.
            if [[ "$(readlink -f /run/current-system/kernel 2>/dev/null)" != "$(readlink -f /run/booted-system/kernel 2>/dev/null)" ]]; then
              echo "WARNING: kernel update deployed but not booted (reboot pending)"
              ${lib.optionalString config.modules.system.maintenance.monitoring.alerts ''
              if [[ ! -f /run/reboot-pending-notified ]]; then
                : > /run/reboot-pending-notified
                ntfy_send "Reboot Pending on $(hostname)" "default" "warning" "Kernel update deployed but not booted. Run: sudo reboot"
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
              ntfy_send "ZFS Pool Issue on $(hostname)" "urgent" "warning" "$zpool_status"
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

        # Deployment switch owned by systemd, not the SSH session. The deploy aliases
        # stage the build with `nh os build -o /tmp/nh-result` and then run
        # `systemctl start --wait nixos-deploy`. Because the job is a systemd unit, a
        # network timeout or SSH disconnect cannot kill the switch mid-flight and leave
        # the box half-deployed; systemd also activates home-manager/logind afterwards.
        nixos-deploy = {
          description = "NixOS deployment switch (detached from the invoking SSH session)";
          after = ["nix-daemon.service" "network-online.target"];
          wants = ["network-online.target"];
          path = [config.system.path pkgs.nh];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
            Group = "root";
          };
          script = ''
            set -euo pipefail

            result=/tmp/nh-result
            if [[ ! -e "$result" ]]; then
              echo "nixos-deploy: no staged result at $result" >&2
              exit 1
            fi

            # Same invocation as the old aliases (--diff never) minus the flake eval:
            # nh deploys exactly the guarded closure staged in /tmp/nh-result.
            nh os switch -d never "$result"
          '';
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
            exec > >(tee -a /var/log/network-maintenance.log) 2>&1
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
                echo "kernel update pending; rebooting to apply"
                ${pkgs.systemd}/bin/systemctl reboot
              fi
            ''}

            echo "=== maintenance window finished at $(date) ==="
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
            Group = "root";
            TimeoutStartSec = 600;
          };
        };
      };

      timers = {
        nixos-auto-update = lib.mkIf config.modules.system.maintenance.autoUpdate.enable {
          description = "Timer for automatic NixOS flake updates";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = config.modules.system.maintenance.autoUpdate.schedule;
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

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
