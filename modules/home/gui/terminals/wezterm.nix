{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require("wezterm")
      local config = wezterm.config_builder()
      local act = wezterm.action

      config.font_size = 14.0
      config.audible_bell = "Disabled"
      config.color_scheme = "Tomorrow Night"
      config.hide_tab_bar_if_only_one_tab = true
      config.window_background_opacity = 0.75

      -- Padding matching ghostty configuration
      config.window_padding = {
        left = 16,
        right = 16,
        top = 16,
        bottom = 16,
      }

      -- temporary fix for Hyprland
      -- config.enable_wayland = false

      config.mouse_bindings = {
        {
          event = { Down = { streak = 1, button = "Right" } },
          mods = "NONE",
          action = wezterm.action_callback(function(window, pane)
            local has_selection = window:get_selection_text_for_pane(pane) ~= ""
            if has_selection then
              window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
              window:perform_action(act.ClearSelection, pane)
            else
              window:perform_action(act({ PasteFrom = "Clipboard" }), pane)
            end
          end),
        },
      }

      -- WSL launch entries for WezTerm launcher (Ctrl+Shift+L)
      -- Requires WSL distribution named "NixOS" (nixos-wsl default)
      config.launch_menu = {
        {
          label = "WSL NixOS (Zellij)",
          args = { "wsl.exe", "-d", "NixOS", "--cd", "~" },
        },
        {
          label = "WSL NixOS (Herdr)",
          args = { "wsl.exe", "-d", "NixOS", "--cd", "~", "--", "fish", "-c", "herdr" },
        },
      }

      return config
    '';
  };
}
