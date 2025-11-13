# Centralized default values for the entire NixOS configuration
# This file serves as the single source of truth for system-wide defaults
# All values can be overridden per-host using lib.mkDefault
rec {
  # System-wide defaults (apply to all hosts unless overridden)
  system = {
    # NixOS state version - determines compatibility with Home Manager releases
    version = "25.11";

    # Default system architecture for all hosts
    architecture = "x86_64-linux";

    # Default primary user for all hosts
    user = "schausberger";

    # Default timezone
    timeZone = "Europe/Vienna";

    # Default system locale
    locale = "en_US.UTF-8";
  };

  # Personal information (used for git config, etc.)
  personalInfo = {
    name = "Felix Schausberger";
    # Email is retrieved from sops secrets at runtime: private/email
  };

  # Common paths (automatically derived from system.user where applicable)
  paths = rec {
    # Home directory - auto-generated from username
    homeDir = "/home/${system.user}";

    # NixOS configuration repository
    nixosConfig = "/per/etc/nixos";

    # Obsidian vault location
    obsidianVault = "${homeDir}/Documents/Obsidian";

    # Repositories directory
    repos = "/per/repos";

    # Sops age key location
    sopsKeyFile = "/per/system/sops-key.txt";

    # System mount directories
    mountDirs = {
      base = "/per/mnt";
      gdrive = "/per/mnt/gdrive";
    };
  };
}
