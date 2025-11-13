{
  lib,
  pkgs,
  ...
}: let
  # Use static memory configuration instead of runtime detection
  # Runtime memory detection doesn't work reliably during Nix evaluation
  # 16GB is a reasonable default for this system based on the hardware
  getTotalMemoryGB = 16;

  # Calculate ARC limits based on system memory
  # Desktop-optimized: 30% max for desktop/development systems (not storage servers)
  # Reference: https://blog.thalheim.io/2025/10/17/zfs-ate-my-ram-understanding-the-arc-cache/
  # - Storage servers can use 50%, desktops should use 25-30%
  # - Settings balanced for future dedicated swap partition
  arcMaxGB = lib.max 1 (getTotalMemoryGB * 0.3);
  arcMinGB = lib.max 1 (getTotalMemoryGB * 0.125); # 12.5% minimum (2GB floor)

  # Convert to bytes for kernel parameter
  arcMaxBytes = toString (builtins.floor (arcMaxGB * 1024 * 1024 * 1024));
  arcMinBytes = toString (builtins.floor (arcMinGB * 1024 * 1024 * 1024));
in {
  # ZFS performance optimization and ARC tuning
  boot.kernelParams = [
    # ZFS ARC (Adaptive Replacement Cache) tuning
    # ARC is ZFS's intelligent cache that adapts between MRU and MFU algorithms
    "zfs.zfs_arc_max=${arcMaxBytes}" # Maximum ARC size (30% of RAM for desktop)
    "zfs.zfs_arc_min=${arcMinBytes}" # Minimum ARC size (12.5% of RAM, 2GB floor)

    # ARC performance tuning
    "zfs.zfs_arc_meta_limit_percent=75" # Allow 75% of ARC for metadata (default 75%)
    "zfs.zfs_arc_dnode_limit_percent=10" # Limit dnode cache to 10% of meta limit

    # Prefetch tuning for better sequential read performance
    "zfs.zfs_prefetch_disable=0" # Enable prefetching (default)
    "zfs.zfs_max_recordsize=16777216" # Max record size 16MB (for large files)

    # TXG (Transaction Group) tuning for better write performance
    "zfs.zfs_txg_timeout=5" # Shorter TXG timeout (5s vs 30s default)
    "zfs.zfs_dirty_data_max_percent=25" # Allow up to 25% of ARC for dirty data

    # Scrub performance tuning
    "zfs.zfs_scrub_delay=0" # No delay between scrub I/Os (faster scrubs)
    "zfs.zfs_scan_vdev_limit=16777216" # 16MB scan limit per vdev
  ];

  # ZFS services configuration
  services.zfs = {
    # Automatic scrubbing for data integrity
    # Scrubs detect and repair silent data corruption
    autoScrub = {
      enable = true;
      interval = "monthly"; # Monthly scrubs balance performance and integrity
      pools = []; # Empty means all pools
    };

    # Automatic snapshot management
    # Provides point-in-time recovery with automatic cleanup
    autoSnapshot = {
      enable = true;
      # Snapshot retention policy balances storage usage with recovery options
      frequent = 8; # 15-minute snapshots, keep 8 (2 hours coverage)
      hourly = 24; # Hourly snapshots, keep 24 (1 day coverage)
      daily = 7; # Daily snapshots, keep 7 (1 week coverage)
      weekly = 4; # Weekly snapshots, keep 4 (1 month coverage)
      monthly = 12; # Monthly snapshots, keep 12 (1 year coverage)
    };

    # ZFS Event Daemon for monitoring and notifications
    zed = {
      # Email notifications for critical events (requires mail setup)
      # enableMail = false;  # Set to true and configure mail if desired

      settings = {
        # Automatically replace failed drives if spares are available
        ZED_SPARE_ON_CHECKSUM_ERRORS = 10; # Replace after 10 checksum errors
        ZED_SPARE_ON_IO_ERRORS = 1; # Replace after 1 I/O error

        # Scrub after resilver to ensure data integrity
        ZED_SCRUB_AFTER_RESILVER = true;

        # Use syslog for logging events
        ZED_USE_SYSLOG = true;
      };
    };

    # Trim support for SSDs to maintain performance
    trim = {
      enable = true;
      interval = "weekly"; # Weekly TRIM balances SSD wear and performance
    };
  };

  # Additional ZFS-related system configuration
  boot = {
    supportedFilesystems = ["zfs"];

    # Ensure ZFS pools are imported early in boot process
    zfs = {
      forceImportRoot = false; # Use cachefile for faster imports
      forceImportAll = false; # Don't force import of all pools
    };

    # ZFS module parameters for additional tuning
    extraModprobeConfig = ''
      # L2ARC (Level 2 ARC) tuning for systems with SSDs
      # L2ARC extends ARC with SSD storage for larger cache
      options zfs l2arc_write_max=134217728          # 128MB max L2ARC write rate
      options zfs l2arc_write_boost=268435456        # 256MB initial write boost
      options zfs l2arc_headroom=8                   # L2ARC headroom multiplier

      # Compression performance tuning
      options zfs zfs_compressed_arc_enabled=1        # Keep compressed data in ARC

      # Checksum verification tuning
      options zfs zfs_fletcher_4_impl=fastest        # Use fastest Fletcher-4 implementation
    '';
  };

  # System packages for ZFS management and monitoring
  environment.systemPackages = with pkgs; [
    # ZFS utilities are included by default when ZFS is enabled
    # Additional monitoring and management tools
    sanoid # Advanced snapshot management (includes syncoid)
  ];
}
