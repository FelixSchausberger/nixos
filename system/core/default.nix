# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
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
  time.timeZone = lib.mkDefault defaults.system.timeZone;

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
  # Use lib.mkDefault for all sysctl values to allow performance profiles and
  # host-specific configs to override these baseline settings
  boot.kernel.sysctl = {
    # Memory management
    "vm.swappiness" = lib.mkDefault 10; # Reduce swap usage preference
    "vm.vfs_cache_pressure" = lib.mkDefault 50; # Keep directory/inode cache longer

    # Memory writeback tuning for better responsiveness
    "vm.dirty_background_ratio" = lib.mkDefault 5; # Start background writeback early
    "vm.dirty_ratio" = lib.mkDefault 10; # Force sync at 10% dirty pages
    "vm.dirty_writeback_centisecs" = lib.mkDefault 100; # Writeback every 1s (default 5s)
    "vm.dirty_expire_centisecs" = lib.mkDefault 3000; # Expire dirty pages after 30s (default 30s)

    # Build performance optimizations
    "kernel.sched_autogroup_enabled" = lib.mkDefault 0; # Better for build workloads
    # Note: vm.max_map_count is already set by NixOS to 1048576
    "kernel.sched_migration_cost_ns" = lib.mkDefault 5000000; # Reduce CPU migration overhead

    # I/O scheduler optimizations
    "vm.page-cluster" = lib.mkDefault 0; # Disable read-ahead for SSDs
    "vm.watermark_boost_factor" = lib.mkDefault 0; # Disable memory watermark boosting for better performance

    # Network performance tuning
    "net.core.rmem_max" = lib.mkDefault 134217728; # 128MB receive buffer
    "net.core.wmem_max" = lib.mkDefault 134217728; # 128MB send buffer
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 65536 134217728"; # TCP receive buffer
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 134217728"; # TCP send buffer
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr"; # Better congestion control
    "net.core.default_qdisc" = lib.mkDefault "cake"; # Modern queueing discipline

    # Note: Inotify limits (max_user_watches=524288, max_user_instances=524288) are
    # already set to good defaults by NixOS in nixos/modules/config/sysctl.nix

    # Note: Security settings (kernel.kptr_restrict, rp_filter) are already set
    # by NixOS defaults in nixos/modules/config/sysctl.nix, so we don't override them
  };

  system.stateVersion = lib.mkDefault defaults.system.version;
}
