# Nightly quiet-hours power policy (default 00:00-09:00).
# A 1L chassis (ThinkCentre M920q) has a single blower; its idle noise is set
# by how aggressively the CPU is allowed to spike. Lowering the
# energy_performance_preference (EPP) and disabling turbo during the quiet
# window drops sustained package temperature, keeping the fan on its slowest
# curve while services stay fully available - nothing is stopped, only the
# performance/latency profile changes. Scheduled jobs stay out of the window
# anyway (quiet-window timer overrides on the host), so the throughput loss
# during 00:00-09:00 is invisible.
{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.modules.system.nightQuiet;

  # One script, two directions. Iterating every cpufreq dir keeps core count
  # generic so the module is host-agnostic; writing applies per-CPU state.
  setState = pkgs.writeShellScript "night-quiet-set-state" ''
    set -eu

    state="$1"
    case "$state" in
      night)
        epp="${cfg.nightEpp}"
        turbo=1
        ;;
      day)
        epp="${cfg.dayEpp}"
        turbo=0
        ;;
      *)
        echo "usage: $0 night|day" >&2
        exit 2
        ;;
    esac

    for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
      if [ -f "$f" ]; then
        echo "$epp" > "$f"
      fi
    done

    # intel_pstate-specific global switch (absent on amd_pstate).
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
      echo "$turbo" > /sys/devices/system/cpu/intel_pstate/no_turbo
    fi
  '';
in {
  options.modules.system.nightQuiet = {
    enable = lib.mkEnableOption "nightly quiet-hours CPU power policy (EPP + turbo)";

    quietWindow = {
      startTime = lib.mkOption {
        type = lib.types.str;
        default = "00:00:00";
        example = "23:00:00";
        description = "Calendar time when the quiet policy applies.";
      };

      endTime = lib.mkOption {
        type = lib.types.str;
        default = "09:00:00";
        example = "08:00:00";
        description = "Calendar time when day policy is restored.";
      };
    };

    # Values restored outside the window: intel_pstate defaults EPP to
    # balance_performance and enables turbo boost.
    dayEpp = lib.mkOption {
      type = lib.types.str;
      default = "balance_performance";
      description = "energy_performance_preference outside the quiet window.";
    };

    nightEpp = lib.mkOption {
      type = lib.types.str;
      default = "power";
      description = "energy_performance_preference during the quiet window.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.night-quiet-on = {
      description = "Night-quiet CPU policy (EPP ${cfg.nightEpp}, turbo off)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${setState} night";
      };
      unitConfig.ConditionPathExists = "/sys/devices/system/cpu/cpu0/cpufreq";
    };

    systemd.services.night-quiet-off = {
      description = "Restore day CPU policy (EPP ${cfg.dayEpp}, turbo on)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${setState} day";
      };
      unitConfig.ConditionPathExists = "/sys/devices/system/cpu/cpu0/cpufreq";
    };

    systemd.timers.night-quiet-on = {
      wantedBy = ["timers.target"];
      timerConfig = {
        # Persistent: if the box was down/rebooted inside the window, catch
        # up immediately so a 03:00 boot still lands in quiet mode.
        OnCalendar = cfg.quietWindow.startTime;
        Persistent = true;
        AccuracySec = "1min";
      };
    };

    systemd.timers.night-quiet-off = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.quietWindow.endTime;
        Persistent = true;
        AccuracySec = "1min";
      };
    };
  };
}
