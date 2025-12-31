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
      {
        directory = ".zen/browsers";
        method = "symlink";
      }
      {
        directory = ".zen/default";
        method = "symlink";
      }
      {
        directory = ".zen/Profile Groups";
        method = "symlink";
      }

      # Zen browser cache for performance
      {
        directory = ".cache/zen";
        method = "symlink";
      }
      {
        directory = ".local/share/zen";
        method = "symlink";
      }
    ];

    # Additional config files for GUI applications
    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
      ".zen/profiles.ini"
    ];
  };
}
