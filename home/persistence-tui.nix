{inputs, ...}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  # Base TUI persistence configuration for all systems
  # This defines essential data that survives system reboots in an impermanent setup
  home.persistence."/per/home" = {
    # Essential directories that must persist
    directories = [
      # Development tool configurations and caches
      ".docker"
      ".cargo"
      ".rustup"
      ".npm"
      ".cache/pip"
      ".vscode"

      # Trash bin for rm-improved
      ".local/share/graveyard"

      # Rclone cache for faster access to cloud files
      ".cache/rclone"

      # Zellij plugin permissions cache (avoids re-prompting after reboot)
      ".cache/zellij"
    ];
  };
}
