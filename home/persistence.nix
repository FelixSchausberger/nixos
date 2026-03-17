{config, ...}: {
  imports = [
    ./persistence-tui.nix
  ];

  # GUI-specific persistence extensions
  # This extends the base TUI persistence with GUI application data
  home.persistence."/per/home/${config.home.username}" = {
    # Additional directories for GUI applications
    directories = [
      # Firefox XDG directories (Firefox 147+ supports XDG Base Directory)
      {
        directory = ".local/state/firefox";
        method = "symlink";
      }
      {
        directory = ".cache/firefox";
        method = "symlink";
      }

      # Most important VSCode data - extensions and global storage
      {
        directory = ".config/Code/User/extensions";
        method = "symlink";
      }
      {
        directory = ".config/Code/User/globalStorage";
        method = "symlink";
      }

      # Spotify offline music cache
      {
        directory = ".cache/spotify/Storage";
        method = "symlink";
      }

      # Task manager database
      {
        directory = ".local/share/io.github.alainm23.planify";
        method = "symlink";
      }

      # Zen browser essential data only - persist entire default profile
      # XDG path since zen-browser 18.18.6b (previously ~/.zen)
      {
        directory = ".config/zen/browsers";
        method = "symlink";
      }
      {
        directory = ".config/zen/default";
        method = "symlink";
      }
      {
        directory = ".config/zen/Profile Groups";
        method = "symlink";
      }
    ];

    # Additional config files for GUI applications
    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
      ".config/zen/profiles.ini"
    ];
  };
}
