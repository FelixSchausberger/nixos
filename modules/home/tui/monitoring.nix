{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.monitoring = {
    enable = lib.mkEnableOption "modern system monitoring tools";
  };

  config = lib.mkIf config.programs.monitoring.enable {
    home.packages = with pkgs; [
      # Modern system monitor with beautiful TUI
      bottom # btm - cross-platform system monitor (htop/ytop alternative)

      # Modern I/O monitoring
      bandwhich # Network utilization by process

      # Modern disk usage analyzer
      dua # Disk Usage Analyzer - fast du alternative with TUI
      dust # du alternative with tree view

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

    # Configure bottom (btm) using native home-manager options
    programs.bottom = {
      enable = true;
      settings = {
        flags = {
          # UI settings
          hide_time = false;
          hide_table_gap = false;
          show_table_scroll_position = true;

          # Temperature settings
          temperature_type = "celsius";

          # Default widget layout
          default_widget_type = "proc";

          # Update rates (in milliseconds)
          rate = 1000;

          # Memory settings
          mem_as_value = false;

          # Network settings
          use_old_network_legend = false;
          network_use_binary_prefix = false;
          network_use_bytes = false;
          network_use_log = false;

          # Process settings
          group_processes = false;
          case_sensitive = false;
          whole_word = false;
          regex = false;
        };

        colors = {
          # Color scheme (catppuccin-mocha inspired)
          table_header_color = "LightBlue";
          all_entry_color = "White";
          avg_entry_color = "Yellow";
          cpu_core_colors = ["LightMagenta" "LightYellow" "LightCyan" "LightGreen" "LightBlue" "LightRed" "Cyan" "Green" "Blue" "Red"];
          ram_color = "LightMagenta";
          swap_color = "LightYellow";
          arc_color = "LightCyan";
          gpu_core_colors = ["LightMagenta" "LightYellow" "LightCyan" "LightGreen"];
          rx_color = "LightCyan";
          tx_color = "LightGreen";
          widget_title_color = "Gray";
          border_color = "Gray";
          highlighted_border_color = "LightBlue";
          text_color = "Gray";
          selected_text_color = "Black";
          selected_bg_color = "LightBlue";
          high_battery_color = "green";
          medium_battery_color = "yellow";
          low_battery_color = "red";
        };
      };
    };

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
