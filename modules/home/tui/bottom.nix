{
  config,
  lib,
  ...
}: {
  options.programs.bottom-custom = {
    enable = lib.mkEnableOption "bottom system monitor with custom configuration";
  };

  config = lib.mkIf config.programs.bottom-custom.enable {
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
          # Color scheme (catppuccin-macchiato inspired)
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
  };
}
