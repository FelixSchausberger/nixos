# Nightly quiet-hours power policy (default 00:00-09:00).
# A 1L chassis (ThinkCentre M920q) has a single blower; its idle noise is set
# by how aggressively the CPU is allowed to spike. Lowering the
# energy_performance_preference (EPP) and disabling turbo during the quiet
# window drops sustained package temperature, keeping the fan on its slowest
# curve while services stay fully available - only the CPU power policy
# changes. The auto-cpufreq tuner is suspended while the window is active so
# it cannot re-apply EPP and turbo behind this module's back; it resumes at
# the day boundary. Scheduled jobs stay out of the window anyway (quiet-window
# timer overrides on the host), so the throughput loss during 00:00-09:00 is
# invisible.
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

    # A Persistent timer fires both directions when the host boots after both
    # edges have passed (the on-disk stamps predate the boot); apply a
    # transition only when it matches the wall clock, so a daytime boot is not
    # left in the night profile and a boot inside the window is not flipped to
    # the day one.
    now="$(${pkgs.coreutils}/bin/date +%H:%M:%S)"
    start="${cfg.quietWindow.startTime}"
    end="${cfg.quietWindow.endTime}"
    in_window=0
    if [[ "$start" < "$end" ]]; then
      if [[ ! "$now" < "$start" ]] && [[ "$now" < "$end" ]]; then in_window=1; fi
    else
      if [[ ! "$now" < "$start" ]] || [[ "$now" < "$end" ]]; then in_window=1; fi
    fi

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

    if [ "$state" = night ] && [ "$in_window" = 0 ]; then exit 0; fi
    if [ "$state" = day ] && [ "$in_window" = 1 ]; then exit 0; fi

    ${lib.optionalString config.services.auto-cpufreq.enable ''
      # auto-cpufreq re-applies EPP and re-enables turbo above 20% CPU load
      # within seconds, undoing the writes below; suspend it while the window
      # is active and resume it at the day boundary.
      if [ "$state" = night ]; then
        ${pkgs.systemd}/bin/systemctl stop auto-cpufreq.service
      else
        ${pkgs.systemd}/bin/systemctl start auto-cpufreq.service
      fi
    ''}

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
      # On a reboot inside the window both units start in the same transaction;
      # order after auto-cpufreq so the suspend in the script lands once it is
      # actually up, rather than racing its start.
      after = lib.optionals config.services.auto-cpufreq.enable ["auto-cpufreq.service"];
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
