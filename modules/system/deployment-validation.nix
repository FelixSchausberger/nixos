{
  config,
  lib,
  pkgs,
  ...
}: let
  wslEnabled = config ? wsl && (config.wsl.enable or false);
in {
  options.modules.system.deploymentValidation = {
    enable = lib.mkEnableOption "deployment validation and integrity checks" // {default = true;};

    preActivation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run validation checks before activation";
      };

      checks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "essential-paths"
          "systemd-services"
          "shell-availability"
        ];
        description = "Pre-activation checks to run";
      };
    };

    postActivation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run smoke tests after activation";
      };

      timeout = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Timeout in seconds for post-activation tests";
      };
    };

    criticalServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "sshd"
        "systemd-journald"
        "dbus"
      ];
      description = "Services that must exist and be valid";
    };

    essentialPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/run/current-system/sw/bin/bash"
        "/run/current-system/sw/bin/systemctl"
        "/etc/nixos"
        "/nix/store"
      ];
      description = "Paths that must exist after activation";
    };

    alertOnFailure = lib.mkEnableOption "send alerts when validation fails";
  };

  config = lib.mkIf config.modules.system.deploymentValidation.enable {
    # Pre-activation validation script
    system.activationScripts.deploymentValidation = lib.mkIf config.modules.system.deploymentValidation.preActivation.enable {
      text = ''
        echo "Running pre-activation validation checks..."

        validation_failed=0

        ${lib.optionalString (builtins.elem "essential-paths" config.modules.system.deploymentValidation.preActivation.checks) ''
          # Check essential paths exist
          echo "Checking essential paths..."
          ${lib.concatMapStringsSep "\n" (path: ''
              if [[ ! -e "${path}" ]]; then
                echo "ERROR: Essential path missing: ${path}"
                validation_failed=1
              fi
            '')
            config.modules.system.deploymentValidation.essentialPaths}
        ''}

        ${lib.optionalString (builtins.elem "systemd-services" config.modules.system.deploymentValidation.preActivation.checks) ''
          # Check critical services are defined
          echo "Checking critical services..."
          ${lib.concatMapStringsSep "\n" (service: ''
              if ! ${pkgs.systemd}/bin/systemctl cat ${service}.service &>/dev/null; then
                echo "WARNING: Critical service not found: ${service}"
                # Don't fail activation for missing services, just warn
              fi
            '')
            config.modules.system.deploymentValidation.criticalServices}
        ''}

        ${lib.optionalString (builtins.elem "shell-availability" config.modules.system.deploymentValidation.preActivation.checks) ''
          # Verify shells are executable
          echo "Checking shell availability..."
          for shell in /run/current-system/sw/bin/bash /run/current-system/sw/bin/sh; do
            if [[ -x "$shell" ]]; then
              if ! "$shell" -c 'exit 0' 2>/dev/null; then
                echo "ERROR: Shell exists but is not functional: $shell"
                validation_failed=1
              fi
            fi
          done
        ''}

        if [[ $validation_failed -eq 1 ]]; then
          echo "Pre-activation validation FAILED"
          echo "Activation will continue, but system may be unstable"
          # Don't exit 1 here - allow activation to proceed but warn
        else
          echo "Pre-activation validation PASSED"
        fi
      '';
      deps = [];
    };

    # Post-activation smoke test service
    systemd.services.post-activation-smoke-test = lib.mkIf config.modules.system.deploymentValidation.postActivation.enable {
      description = "Post-activation smoke tests for system integrity";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = config.modules.system.deploymentValidation.postActivation.timeout;
      };

      script = ''
        set -euo pipefail

        echo "Running post-activation smoke tests..."

        # Test: systemd is running properly (don't wait indefinitely)
        system_state=$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null || echo "unknown")
        if [[ "$system_state" != "running" ]]; then
          echo "WARNING: systemd reports state: $system_state"
        fi

        # Test: Critical services are active or can be started
        ${lib.concatMapStringsSep "\n" (service: ''
            if ${pkgs.systemd}/bin/systemctl is-enabled ${service}.service &>/dev/null; then
              if ! ${pkgs.systemd}/bin/systemctl is-active ${service}.service &>/dev/null; then
                echo "WARNING: Critical service not active: ${service}"
              fi
            fi
          '')
          config.modules.system.deploymentValidation.criticalServices}

        # Test: Essential paths still exist
        ${lib.concatMapStringsSep "\n" (path: ''
            if [[ ! -e "${path}" ]]; then
              echo "ERROR: Essential path missing after activation: ${path}"
              exit 1
            fi
          '')
          config.modules.system.deploymentValidation.essentialPaths}

        # Test: Shells are functional
        if [[ -x /run/current-system/sw/bin/bash ]]; then
          /run/current-system/sw/bin/bash -c 'exit 0' || {
            echo "ERROR: Bash shell is not functional"
            exit 1
          }
        fi

        # Test: Nix store is accessible (quick check only)
        if [[ ! -d /nix/store ]]; then
          echo "ERROR: Nix store not accessible"
          exit 1
        fi

        # Platform-specific tests
        ${lib.optionalString wslEnabled ''
          # WSL-specific checks
          if [[ ! -d /mnt/c ]]; then
            echo "WARNING: Windows C: drive not mounted at /mnt/c"
          fi
        ''}

        ${lib.optionalString (config.boot.zfs.enabled or false) ''
          # ZFS-specific checks
          if command -v zpool &>/dev/null; then
            if ! zpool status -x | grep -q "all pools are healthy"; then
              echo "WARNING: ZFS pools are not healthy"
            fi
          fi
        ''}

        echo "Post-activation smoke tests PASSED"
      '';
    };

    # Validation utility script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "validate-system" ''
        set -euo pipefail

        if [[ -t 1 ]]; then
          fmt_bold=$'\033[1m'
          fmt_reset=$'\033[0m'
          fmt_green=$'\033[32m'
          fmt_yellow=$'\033[33m'
          fmt_red=$'\033[31m'
          fmt_blue=$'\033[34m'
        else
          fmt_bold=""
          fmt_reset=""
          fmt_green=""
          fmt_yellow=""
          fmt_red=""
          fmt_blue=""
        fi

        underline() {
          local text="$1"
          printf "%s\n" "$(echo "$text" | sed 's/./-/g')"
        }

        section() {
          local title="$1"
          printf "\n%b%s%b\n" "$fmt_bold" "$title" "$fmt_reset"
          underline "$title"
        }

        status_line() {
          local level="$1"
          local label="$2"
          local message="''${3:-}"
          local icon color
          case "$level" in
            ok)
              icon="✓"
              color="$fmt_green"
              ;;
            warn)
              icon="⚠"
              color="$fmt_yellow"
              ;;
            err)
              icon="✗"
              color="$fmt_red"
              ;;
            *)
              icon="•"
              color="$fmt_blue"
              ;;
          esac
          if [[ -n "$message" ]]; then
            message=" - $message"
          fi
          printf "  %b%s%b %s%s\n" "$color" "$icon" "$fmt_reset" "$label" "$message"
        }

        generation_from_symlinks() {
          local current="$1"
          local nullglob_state
          nullglob_state=$(shopt -p nullglob 2>/dev/null || echo "shopt -u nullglob")
          shopt -s nullglob
          for link in /nix/var/nix/profiles/system-*-link; do
            local target
            target=$(readlink -f "$link" 2>/dev/null || continue)
            if [[ "$target" == "$current" ]]; then
              eval "$nullglob_state"
              basename "$link" | sed 's/^system-//; s/-link$//'
              return 0
            fi
          done
          eval "$nullglob_state"
          return 1
        }

        printf "%bSystem Integrity Validation%b\n" "$fmt_bold" "$fmt_reset"
        printf "============================\n"

        section "Systemd"
        system_state="$(${pkgs.systemd}/bin/systemctl is-system-running 2>/dev/null || true)"
        if [[ -z "$system_state" ]]; then
          system_state="unknown"
        fi
        case "$system_state" in
          running)
            status_line ok "State" "running"
            ;;
          degraded)
            status_line warn "State" "degraded (one or more units failed)"
            ;;
          starting|stopping)
            status_line warn "State" "$system_state (systemd still converging)"
            ;;
          maintenance|rescue|emergency)
            status_line err "State" "$system_state (system in maintenance mode)"
            ;;
          *)
            status_line info "State" "$system_state"
            ;;
        esac

        section "Failed Services"
        failed_units="$(${pkgs.systemd}/bin/systemctl --failed --no-legend --plain 2>/dev/null || true)"
        if [[ -z "''${failed_units//[[:space:]]/}" ]]; then
          status_line ok "Systemd" "no failed units"
        else
          while read -r unit load active sub rest; do
            [[ -z "''${unit:-}" ]] && continue
            detail="''${active:-unknown}/''${sub:-unknown}"
            if [[ -n "''${rest:-}" ]]; then
              detail="$detail - $rest"
            fi
            status_line err "$unit" "$detail"
          done <<< "$failed_units"
        fi

        section "Essential Paths"
        ${lib.concatMapStringsSep "\n" (path: ''
            if [[ -e "${path}" ]]; then
              status_line ok "${path}" ""
            else
              status_line err "${path}" "missing"
            fi
          '')
          config.modules.system.deploymentValidation.essentialPaths}

        section "Critical Services"
        ${lib.concatMapStringsSep "\n" (service: ''
            if ${pkgs.systemd}/bin/systemctl is-active ${service}.service &>/dev/null; then
              status_line ok "${service}" "active"
            elif ${pkgs.systemd}/bin/systemctl is-enabled ${service}.service &>/dev/null; then
              status_line warn "${service}" "enabled but inactive"
            else
              status_line err "${service}" "not found or disabled"
            fi
          '')
          config.modules.system.deploymentValidation.criticalServices}

        section "Shells"
        shells=(
          "bash:/run/current-system/sw/bin/bash"
        )
        if command -v fish &>/dev/null; then
          shells+=("fish:$(command -v fish)")
        fi
        for entry in "''${shells[@]}"; do
          IFS=: read -r name path <<< "$entry"
          if [[ -x "$path" ]]; then
            if "$path" -c 'exit 0' 2>/dev/null; then
              status_line ok "$name" "$path"
            else
              status_line err "$name" "exists but failed to execute ($path)"
            fi
          else
            status_line warn "$name" "not installed"
          fi
        done

        section "Nix Store"
        if [[ -d /nix/store && -r /nix/store ]]; then
          store_count=$(find /nix/store -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
          status_line ok "/nix/store" "$store_count entries accessible"
        else
          status_line err "/nix/store" "not accessible"
        fi

        section "Current Generation"
        current_path=$(readlink -f /run/current-system 2>/dev/null || echo "unknown")
        status_line info "Path" "$current_path"

        profile="/nix/var/nix/profiles/system"
        if generation=$(generation_from_symlinks "$current_path" 2>/dev/null); then
          status_line ok "Generation" "$generation"
        elif [[ -r "$profile" ]]; then
          current_line="$(${pkgs.nix}/bin/nix-env -p "$profile" --list-generations 2>/dev/null | grep '(current)' || true)"
          if [[ -n "''${current_line:-}" ]]; then
            generation=$(echo "$current_line" | ${pkgs.gawk}/bin/awk '{print $1}')
            status_line ok "Generation" "$generation"
          else
            status_line warn "Generation" "profile readable but current generation unknown"
          fi
        else
          status_line info "Generation" "unavailable (profile unreadable without sudo)"
        fi

        printf "\n%bValidation complete%b %s\n" "$fmt_bold" "$fmt_reset" "$(date -Iseconds)"
      '')
    ];
  };
}
