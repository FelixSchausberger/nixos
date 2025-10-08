{
  config,
  inputs,
  ...
}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  # Base TUI persistence configuration for all systems
  # This defines essential data that survives system reboots in an impermanent setup
  home.persistence."/per/home/${config.home.username}" = {
    allowOther = true;
    removePrefixDirectory = false;

    # Essential directories that must persist - using symlinks for better performance
    directories = [
      # Development tool configurations and caches
      {
        directory = ".docker";
        method = "symlink";
      }
      {
        directory = ".cargo";
        method = "bindfs";
      }
      {
        directory = ".rustup";
        method = "bindfs";
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

      # Trash bin for rm-improved
      {
        directory = ".local/share/graveyard";
        method = "symlink";
      }

      # Rclone cache for faster access to cloud files
      {
        directory = ".cache/rclone";
        method = "symlink";
      }
    ];
  };
}
