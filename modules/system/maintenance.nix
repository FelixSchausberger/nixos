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
    };
  };

  config = lib.mkIf config.modules.system.maintenance.enable {
    systemd = {
      services = {
        # Automated flake updates
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

        # System health monitoring
        system-health-check = lib.mkIf config.modules.system.maintenance.monitoring.enable {
          description = "System health monitoring";
          script = ''
            set -eu

            # Check for failed services
            failed_services=$(${pkgs.systemd}/bin/systemctl --failed --no-legend | wc -l)
            if [[ $failed_services -gt 0 ]]; then
              echo "WARNING: $failed_services failed services detected"
              ${pkgs.systemd}/bin/systemctl --failed --no-legend
            fi

            # Check disk space
            root_usage=$(df / | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $root_usage -gt 90 ]]; then
              echo "WARNING: Root filesystem is $root_usage% full"
            fi

            nix_usage=$(df /nix | tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | sed 's/%//')
            if [[ $nix_usage -gt 85 ]]; then
              echo "WARNING: Nix store is $nix_usage% full"
              echo "Consider running: clean"
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
            fi

            # ZFS health check (if ZFS is available)
            if command -v zpool >/dev/null 2>&1; then
              zpool_status=$(zpool status -x)
              if [[ "$zpool_status" != "all pools are healthy" ]]; then
                echo "WARNING: ZFS pool health issues detected:"
                echo "$zpool_status"
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

        # Automated cleanup service
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

            # Clean temporary files
            ${pkgs.systemd}/bin/systemd-tmpfiles --clean

            echo "Cleanup completed at $(date)"
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
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
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
            RandomizedDelaySec = "2h";
          };
        };
      };
    };

    # Security hardening improvements
    security = {
      # Additional kernel hardening
      forcePageTableIsolation = true;
    };

    # Additional sysctl security settings
    boot.kernel.sysctl = {
      # Network security improvements (beyond what's already configured)
      "net.ipv4.conf.all.log_martians" = 1; # Log suspicious packets
      "net.ipv4.conf.default.log_martians" = 1;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1; # Ignore bogus ICMP error responses
      "net.ipv4.tcp_syncookies" = 1; # Enable SYN flood protection

      # Kernel security improvements
      "kernel.dmesg_restrict" = 1; # Restrict dmesg access
      "kernel.kexec_load_disabled" = 1; # Disable kexec
      "kernel.unprivileged_bpf_disabled" = 1; # Disable unprivileged BPF
      "kernel.yama.ptrace_scope" = 2; # Restrict ptrace access

      # File system security
      "fs.protected_hardlinks" = 1; # Prevent hardlink attacks
      "fs.protected_symlinks" = 1; # Prevent symlink attacks
      "fs.protected_fifos" = 2; # Protect FIFOs
      "fs.protected_regular" = 2; # Protect regular files
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
