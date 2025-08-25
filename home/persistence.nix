{
  config,
  inputs,
  ...
}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  # Consolidated persistence configuration for all user data
  # This defines what survives system reboots in an impermanent setup
  home.persistence."/per/home/${config.home.username}" = {
    allowOther = true;
    removePrefixDirectory = false;

    # Essential directories that must persist - using symlinks for better performance
    directories = [
      # Browser data - essential for sessions/bookmarks
      {
        directory = ".mozilla";
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

      # Trash bin for rm-improved
      {
        directory = ".local/share/graveyard";
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

      # Rclone cache for faster access to cloud files
      {
        directory = ".cache/rclone";
        method = "symlink";
      }

      # Development tool configurations and caches
      {
        directory = ".docker";
        method = "symlink";
      }
      {
        directory = ".cargo";
        method = "symlink";
      }
      {
        directory = ".rustup";
        method = "symlink";
      }
      {
        directory = ".npm";
        method = "symlink";
      }
      {
        directory = ".cache/pip";
        method = "symlink";
      }
      {
        directory = ".vscode";
        method = "symlink";
      }
    ];

    # Important config files
    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
      ".zen/profiles.ini"
      ".gitconfig"
      ".config/git/config"
      ".config/gh/config.yml"
    ];
  };
}
