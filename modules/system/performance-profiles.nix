{
  lib,
  config,
  ...
}: let
  cfg = config.hostConfig;
in {
  config = lib.mkMerge [
    # Default profile - no performance tuning, rely on hardware defaults
    (lib.mkIf (cfg.performanceProfile == "default") {
      # No cpuFreqGovernor setting - let hardware config handle it
    })

    # Gaming profile - maximum performance
    (lib.mkIf (cfg.performanceProfile == "gaming") {
      boot.kernelParams = [
        "mitigations=off" # Disable CPU mitigations for performance
        "nohz_full=1-7" # Reduce timer interrupts on CPU cores
      ];

      boot.kernel.sysctl = {
        "vm.swappiness" = lib.mkForce 1; # Minimal swap for gaming
        "kernel.sched_migration_cost_ns" = lib.mkForce 500000; # Lower latency
      };

      # Enable CPU governor for performance
      powerManagement.cpuFreqGovernor = lib.mkForce "performance";
    })

    # Productivity profile - balanced performance and efficiency
    (lib.mkIf (cfg.performanceProfile == "productivity") {
      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

      boot.kernel.sysctl = {
        "vm.swappiness" = lib.mkForce 10; # Balanced swap
        "kernel.sched_autogroup_enabled" = lib.mkForce 1; # Better for desktop workloads
      };
    })

    # Power-saving profile - maximize battery life and reduce thermals
    (lib.mkIf (cfg.performanceProfile == "power-saving") {
      powerManagement.cpuFreqGovernor = lib.mkForce "powersave";

      boot.kernel.sysctl = {
        "vm.dirty_writeback_centisecs" = lib.mkForce 1500; # Reduce disk writes
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
        "vm.swappiness" = lib.mkForce 1; # Avoid swap during builds
        "vm.dirty_ratio" = lib.mkForce 40; # Allow more dirty pages before sync
        "vm.dirty_background_ratio" = lib.mkForce 10; # Start writeback later

        # Scheduler optimizations for parallel builds
        "kernel.sched_autogroup_enabled" = lib.mkForce 0; # Better for make -j
        "kernel.sched_migration_cost_ns" = lib.mkForce 500000; # Reduce migration cost
        "kernel.sched_min_granularity_ns" = lib.mkForce 1000000; # Lower context switch overhead

        # File system performance
        "vm.vfs_cache_pressure" = lib.mkForce 50; # Keep inode/dentry cache
        "fs.inotify.max_user_watches" = lib.mkForce 524288; # For file watching (IDEs, build tools)
      };

      # Maximum CPU performance
      powerManagement.cpuFreqGovernor = lib.mkForce "performance";
    })
  ];
}
