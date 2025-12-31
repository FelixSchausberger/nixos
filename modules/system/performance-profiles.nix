{
  lib,
  config,
  ...
}: let
  cfg = config.hostConfig;
in {
  config = lib.mkMerge [
    # Gaming profile - maximum performance
    (lib.mkIf (cfg.performanceProfile == "gaming") {
      boot.kernelParams = [
        "mitigations=off" # Disable CPU mitigations for performance
        "nohz_full=1-7" # Reduce timer interrupts on CPU cores
      ];

      boot.kernel.sysctl = {
        "vm.swappiness" = 1; # Minimal swap for gaming
        "kernel.sched_migration_cost_ns" = 500000; # Lower latency
      };

      # Enable CPU governor for performance
      powerManagement.cpuFreqGovernor = "performance";
    })

    # Productivity profile - balanced performance and efficiency
    (lib.mkIf (cfg.performanceProfile == "productivity") {
      powerManagement.cpuFreqGovernor = "schedutil";

      boot.kernel.sysctl = {
        "vm.swappiness" = 10; # Balanced swap
        "kernel.sched_autogroup_enabled" = 1; # Better for desktop workloads
      };
    })

    # Power-saving profile - maximize battery life and reduce thermals
    (lib.mkIf (cfg.performanceProfile == "power-saving") {
      powerManagement.cpuFreqGovernor = "powersave";

      boot.kernel.sysctl = {
        "vm.dirty_writeback_centisecs" = 1500; # Reduce disk writes
        "vm.laptop_mode" = 5; # Enable laptop mode
      };

      services.thermald.enable = lib.mkDefault true;
      services.tlp = {
        enable = lib.mkDefault true;
        settings = {
          CPU_SCALING_GOVERNOR_ON_AC = "powersave";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        };
      };
    })

    # Build profile - optimized for compilation and development
    (lib.mkIf (cfg.performanceProfile == "build") {
      boot.kernelParams = [
        "mitigations=off" # Disable CPU mitigations for max performance
        "nohz_full=1-11" # Reduce timer interrupts (Ryzen 5600 has 6C/12T)
        "nowatchdog" # Disable watchdog for slight performance gain
      ];

      boot.kernel.sysctl = {
        # Memory tuning for large builds
        # No lib.mkDefault - naturally overrides core defaults (which use lib.mkDefault)
        "vm.swappiness" = 1; # Avoid swap during builds
        "vm.dirty_ratio" = 40; # Allow more dirty pages before sync
        "vm.dirty_background_ratio" = 10; # Start writeback later

        # Scheduler optimizations for parallel builds
        "kernel.sched_autogroup_enabled" = 0; # Better for make -j
        "kernel.sched_migration_cost_ns" = 500000; # Reduce migration cost
        "kernel.sched_min_granularity_ns" = 1000000; # Lower context switch overhead

        # File system performance
        "vm.vfs_cache_pressure" = 50; # Keep inode/dentry cache

        # Inotify limits moved to system/core/default.nix as universal baseline
        # Build profile inherits: 524288 watches, 8192 instances, 32768 events
      };

      # Maximum CPU performance
      powerManagement.cpuFreqGovernor = "performance";
    })
  ];
}
