# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./persistence.nix
    ./security
    ./users.nix
  ];

  documentation.dev.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # Saves space
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_AT.UTF-8/UTF-8"
    ];
  };

  # Set your time zone.
  time.timeZone = lib.mkDefault "Europe/Vienna";

  programs.fuse.userAllowOther = true;

  # Configure system-wide files.
  environment = {
    etc.nixos.source = "${inputs.self}";

    systemPackages = with pkgs; [
      fuse # Library that allows filesystems to be implemented in user space
      fuse3 # Library that allows filesystems to be implemented in user space
      bindfs # FUSE filesystem for mounting a directory to another location
      xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
    ];

    # Persistence configuration moved to ./persistence.nix for better organization
  };

  services = {
    # Simple interprocess messaging system
    dbus.enable = true;

    # Support for mounting other filesystems
    gvfs.enable = true;
  };

  # Compresses half the ram for use as swap
  zramSwap.enable = true;

  # Enable emergency shell and recovery features
  system.emergency.enable = true;

  # Kernel memory management optimization
  boot.kernel.sysctl = {
    # Memory management
    "vm.swappiness" = 10; # Reduce swap usage preference
    "vm.vfs_cache_pressure" = 50; # Keep directory/inode cache longer

    # Memory writeback tuning for better responsiveness
    "vm.dirty_background_ratio" = 5; # Start background writeback early
    "vm.dirty_ratio" = 10; # Force sync at 10% dirty pages
    "vm.dirty_writeback_centisecs" = 100; # Writeback every 1s (default 5s)
    "vm.dirty_expire_centisecs" = 3000; # Expire dirty pages after 30s (default 30s)

    # Build performance optimizations
    "kernel.sched_autogroup_enabled" = 0; # Better for build workloads
    "vm.max_map_count" = 1048576; # Help with large builds (default 65530)
    "kernel.sched_migration_cost_ns" = 5000000; # Reduce CPU migration overhead

    # I/O scheduler optimizations
    "vm.page-cluster" = 0; # Disable read-ahead for SSDs
    "vm.watermark_boost_factor" = 0; # Disable memory watermark boosting for better performance

    # Network performance tuning
    "net.core.rmem_max" = 134217728; # 128MB receive buffer
    "net.core.wmem_max" = 134217728; # 128MB send buffer
    "net.ipv4.tcp_rmem" = "4096 65536 134217728"; # TCP receive buffer
    "net.ipv4.tcp_wmem" = "4096 65536 134217728"; # TCP send buffer
    "net.ipv4.tcp_congestion_control" = "bbr"; # Better congestion control
    "net.core.default_qdisc" = "cake"; # Modern queueing discipline

    # Security hardening while maintaining performance
    "kernel.kptr_restrict" = 1; # Hide kernel pointers
    "net.ipv4.conf.default.rp_filter" = 1; # Enable reverse path filtering
    "net.ipv4.conf.all.rp_filter" = 1;
  };

  system.stateVersion = lib.mkDefault "25.11";
}
