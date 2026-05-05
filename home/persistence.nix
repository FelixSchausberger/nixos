{...}: {
  imports = [
    ./persistence-tui.nix
  ];

  # GUI-specific persistence extensions
  # This extends the base TUI persistence with GUI application data
  home.persistence."/per/home" = {
    # Additional directories for GUI applications
    directories = [
      # Firefox XDG directories (Firefox 147+ supports XDG Base Directory)
      ".local/state/firefox"
      ".cache/firefox"

      # Most important VSCode data - extensions and global storage
      ".config/Code/User/extensions"
      ".config/Code/User/globalStorage"

      # Spotify offline music cache
      ".cache/spotify/Storage"

      # Task manager database
      ".local/share/io.github.alainm23.planify"

      # Zen browser essential data only - persist entire default profile
      # XDG path since zen-browser 18.18.6b (previously ~/.zen)
      ".config/zen/browsers"
      ".config/zen/default"
      ".config/zen/Profile Groups"
    ];

    # Additional config files for GUI applications
    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
    ];
  };
}
