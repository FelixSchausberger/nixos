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
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
            # Defer to boot-critical services to avoid slow-boot vitals warnings
            Nice = 19;
            IOSchedulingClass = "idle";
            TimeoutStartSec = 600;
            DefaultDependencies = false;
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
            Persistent = true;
            RandomizedDelaySec = "2h";
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
