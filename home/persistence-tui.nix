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
      # Development tool configurations and caches (Rust toolchains ship in
      # per-project flake dev shells, so ~/.cargo and ~/.rustup are not kept)
      ".docker"
      ".npm"
      ".cache/pip"
      ".vscode"

      # Graveyard for rip2 (safe deletion, shared by AI rm shim)
      ".local/share/graveyard"

      # Rclone cache for faster access to cloud files
      ".cache/rclone"

      # Zellij plugin permissions cache and downloaded plugin data
      ".cache/zellij"
      ".local/share/zellij"

      # Contact stack: synced CardDAV collection, vdirsyncer discovery cache
      # and item status (without status the timer demands a re-discover)
      ".local/share/contacts"
      ".local/share/vdirsyncer"

      # Chroncal's SQLite store, seeded config and log
      ".local/share/chroncal"
      ".config/chroncal"
      ".local/state/chroncal"

      # Cfait's offline journal: queued edits that have not reached Nextcloud
      # yet must survive a reboot
      ".local/share/cfait"
    ];
  };
}
