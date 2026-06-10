{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.monitoring = {
    enable = lib.mkEnableOption "modern system monitoring tools";
  };

  imports = [
    ./bottom.nix
  ];

  config = lib.mkIf config.programs.monitoring.enable {
    # Enable bottom with custom configuration
    programs.bottom-custom.enable = true;

    home.packages = with pkgs; [
      # Modern system monitor with beautiful TUI
      bottom # btm - cross-platform system monitor (htop/ytop alternative)

      # Modern I/O monitoring
      bandwhich # Network utilization by process

      # Modern disk usage analyzer
      dua # Disk Usage Analyzer - fast du alternative with TUI
      dust # du alternative with tree view
      dysk # Get information on your mounted disks

      # ZFS-specific monitoring
      zfs-prune-snapshots # Clean up old ZFS snapshots

      # Process monitoring
      procs # ps alternative with colored output

      # Network monitoring
      dog # DNS lookup utility (dig alternative)
      gping # ping with graph

      # Performance analysis
      hyperfine # Command-line benchmarking

      # System information
      fastfetch # System information display (neofetch alternative)
    ];

    # Shell aliases for monitoring tools
    programs.fish.shellAliases = lib.mkIf config.programs.fish.enable {
      # Modern alternatives to classic tools
      "htop" = "btm";
      "top" = "btm --basic";
      "iotop" = "btm --basic -P";
      "ps" = "procs";
      "du" = "dua interactive";
      "ncdu" = "dua interactive";
      # "ping" = "gping";
      "dig" = "dog";
      "bench" = "hyperfine";

      # ZFS monitoring shortcuts
      "zfs-space" = "zfs list -o name,used,avail,refer,mountpoint -t filesystem";
      "zfs-snaps" = "zfs list -t snapshot";
      "zfs-cleanup" = "zfs-prune-snapshots --dry-run";
      "zfs-io" = "zpool iostat -v 1";

      # System overview
      "sysinfo" = "fastfetch";
      "sysmon" = "btm";
      "netmon" = "bandwhich";
    };
  };
}
