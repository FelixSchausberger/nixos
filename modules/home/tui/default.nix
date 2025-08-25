{pkgs, ...}: {
  imports = [
    ./helix # Post-modern modal text editor
    ./neovim.nix # Neovim with basic configuration (replaces nixvim to avoid tree-sitter-ada issue)
    ./yazi # Blazing fast terminal file manager written in Rust, based on async I/O
    ./bat.nix # A cat clone with syntax highlighting and Git integration
    ./bluetui.nix # Bluetooth TUI management tool (kept separate due to config)
    ./claude-code # An agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
    ./direnv.nix # A shell extension that manages your environment
    ./eza.nix # A modern, maintained replacement for ls
    ./fd.nix # A simple, fast and user-friendly alternative to find
    ./fzf.nix # A command-line fuzzy finder written in Go
    ./git.nix # Distributed version control system
    ./jujutsu.nix # Git-compatible DVCS that is both simple and powerful
    ./markdown-oxide.nix # Markdown LSP server inspired by Obsidian
    ./monitoring.nix # Modern system monitoring and performance tools
    ./ollama.nix # Get up and running with large language models locally
    ./rbw.nix # Unofficial Bitwarden CLI for password management
    ./rclone.nix # Sync files and directories to and from major cloud storage
    ./sops.nix # Simple and flexible tool for managing secrets
    # ./spotify-player.nix # Terminal-based Spotify client with full feature parity
    ./typix.nix # Typst: A markup-based typesetting system
  ];

  programs = {
    # cliphist.enable = true; # Wayland clipboard manager
    bottom.enable = true; # A cross-platform graphical process/system monitor
    home-manager.enable = true; # A Nix-based user environment configurator
    nix-index.enable = true; # A files database for nixpkgs

    # Enable modern monitoring tools
    monitoring.enable = true;

    pay-respects = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      options = ["--alias" "f"];
    };

    tealdeer = {
      enable = true;
      settings = {
        updates.auto_update = true;
      };
    };
  };

  home.packages = with pkgs; [
    # clipboard-jh # Cut, copy, and paste anything, anywhere, all from the terminal
    fclones # Efficient Duplicate File Finder and Remover
    lan-mouse # Software KVM switch for sharing mouse and keyboard over network
    lazyjournal # TUI for journalctl, file system logs, as well as Docker and Podman containers
    lstr # Fast, minimalist directory tree viewer written in Rust
    impala # WiFi TUI management tool
    iwd # Modern WiFi daemon (needed by impala)
    nix-inspect # Interactive TUI for inspecting nix configs
    ouch # A CLI for easily compressing and decompressing files and directories
    pik # Process Interactive Kill
    # quickemu # Quickly create and run virtual machines
    ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
    rm-improved # Replacement for rm (replaces both rip.nix and provides better rm)
    # superfile # Pretty fancy and modern terminal file manager
    typst # New markup-based typesetting system that is powerful and easy to learn
    xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
  ];

  services = {
    lorri.enable = true; # Your project's nix-env
  };
}
