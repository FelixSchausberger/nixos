# Unattended hang recovery for physically-unreachable hosts.
#
# Layer           Covers
# hardware WD     wedged PID1/kernel with no lockup detector firing
# lockup panics   detectable soft/hard lockups and hung tasks
# panic=<n>       reboot after a panic instead of idling
# emergency deadman  reboot out of emergency/rescue so systemd-boot boot
#                    counting can roll back to the last-known-good generation
#
# Opt-in per host: only where the machine is genuinely unattended AND boots via
# systemd-boot boot counting (hosts/boot-zfs.nix). On WSL/VMs a reboot has no
# bootloader to advance, and on laptops the user is already at the console.
{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.watchdog;
in {
  options.modules.system.watchdog = {
    enable = lib.mkEnableOption "unattended watchdog and emergency deadman auto-recovery";

    watchdogKernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Watchdog modules forced into initrd so /dev/watchdog exists before
        initrd-stage systemd arms the timer. Host-specific: iTCO_wdt on Intel
        chipsets, sp5100_tco on AMD.
      '';
      example = ["iTCO_wdt"];
    };

    runtimeWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "systemd runtime watchdog timeout (PID1 keepalive window).";
    };

    shutdownWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Watchdog timeout during shutdown; bounds a hung shutdown.";
    };

    initrdWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = ''
        Initrd-stage watchdog timeout. Longer than the runtime value because
        slow (SMR) pool imports can legitimately stall initrd for a while;
        systemd pets continuously as long as PID 1 makes progress.
      '';
    };

    initrdRebootWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "Hard limit on a stalled initrd shutdown/switch-root.";
    };

    hungTaskTimeoutSecs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 240;
      description = ''
        kernel.hung_task_timeout_secs. Kept high because slow (SMR) pool IO can
        legitimately stall tasks for minutes; too low reboot-loops a busy host.
      '';
    };

    panicSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Reboot this many seconds after a kernel panic instead of hanging.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Reboot out of emergency/rescue so boot counting can advance to a fallback.
    system.emergency.deadmanAutoRecover = true;

    # Reboot after a panic instead of hanging forever; no effect on silent hangs.
    boot.kernelParams = ["panic=${toString cfg.panicSeconds}"];

    systemd.settings.Manager = {
      RuntimeWatchdogSec = cfg.runtimeWatchdogSec;
      ShutdownWatchdogSec = cfg.shutdownWatchdogSec;
    };

    boot.initrd.kernelModules = cfg.watchdogKernelModules;
    boot.initrd.systemd.settings.Manager = {
      RuntimeWatchdogSec = cfg.initrdWatchdogSec;
      RebootWatchdogSec = cfg.initrdRebootWatchdogSec;
    };

    # Convert detectable lockups into panics so panic=<n> can reboot them.
    # Sysctl names verified present on the running kernel via sysctl -a.
    boot.kernel.sysctl = {
      "kernel.nmi_watchdog" = 1;
      "kernel.hardlockup_panic" = 1;
      "kernel.softlockup_panic" = 1;
      "kernel.hung_task_panic" = 1;
      "kernel.hung_task_timeout_secs" = cfg.hungTaskTimeoutSecs;
    };
  };
}
