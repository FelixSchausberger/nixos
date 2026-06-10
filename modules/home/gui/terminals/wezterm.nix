{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return {
        -- Uncomment the line below and specify your preferred font if needed
        -- font = wezterm.font("Fira Code NF"),

        font_size = 14.0,  -- Adjust the font size to your preference

        audible_bell = "Disabled",

        -- Choose your preferred color scheme (e.g., "Tomorrow Night")
        color_scheme = "Tomorrow Night",

        -- Hide the tab bar if only one tab is open
        hide_tab_bar_if_only_one_tab = true,

        -- Adjust the window background opacity (0.0 to 1.0)
        window_background_opacity = 0.3,

        -- temporary fix for Hyprland
        -- enable_wayland = false,
      }
    '';
  };
}
