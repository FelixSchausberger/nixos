# Build-time deployment validation: fails evaluation when critical services
# are missing from the generated unit tree instead of warning at activation
# time. Runtime health checks live in modules/system/maintenance.nix
# (system-health-check); interactive inspection stays available through the
# validate-system CLI.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.deploymentValidation;

  missingServices = let
    knownUnit = svc:
      config.systemd.units ? "${svc}.service" || config.systemd.units ? "${svc}.socket";
  in
    builtins.filter (svc: !knownUnit svc) cfg.criticalServices;
in {
  options.modules.system.deploymentValidation = {
    enable =
      lib.mkEnableOption "build-time validation of critical services"
      // {
        default = true;
      };

    criticalServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "sshd"
        "systemd-journald"
        "dbus"
      ];
      description = "Services that must exist in the generated unit tree";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingServices == [];
        message = "deploymentValidation: critical services missing from the unit tree: ${lib.concatStringsSep ", " missingServices}";
      }
    ];

    # Validation utility script for interactive post-deploy inspection.
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

        section "Critical Services"
        ${lib.concatMapStringsSep "\n" (service: ''
            if ${pkgs.systemd}/bin/systemctl is-active ${service}.service &>/dev/null; then
              status_line ok "${service}" "active"
            elif ${pkgs.systemd}/bin/systemctl is-enabled ${service}.service &>/dev/null; then
              status_line warn "${service}" "enabled but inactive"
            elif ${pkgs.systemd}/bin/systemctl is-enabled ${service}.socket &>/dev/null || ${pkgs.systemd}/bin/systemctl is-active ${service}.socket &>/dev/null; then
              status_line ok "${service}" "socket-activated"
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

        section "Reboot"
        current_kernel=$(readlink -f /run/current-system/kernel 2>/dev/null || echo "unknown")
        booted_kernel=$(readlink -f /run/booted-system/kernel 2>/dev/null || echo "unknown")
        if [[ "$current_kernel" == "$booted_kernel" ]]; then
          status_line ok "Kernel" "up to date ($booted_kernel)"
        elif [[ "$current_kernel" == "unknown" || "$booted_kernel" == "unknown" ]]; then
          status_line info "Kernel" "unavailable ($current_kernel vs $booted_kernel)"
        else
          status_line warn "Kernel" "reboot pending: running $booted_kernel -> deployed $current_kernel"
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
