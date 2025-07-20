{pkgs, ...}: {
  imports = [
    ./claude-code.nix # An agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
    ./bat.nix # A cat clone with syntax highlighting and Git integration
    ./direnv.nix # A shell extension that manages your environment
    ./eza.nix # A modern, maintained replacement for ls
    ./fd.nix # A simple, fast and user-friendly alternative to find
    ./fzf.nix # A command-line fuzzy finder written in Go
    ./git.nix # Distributed version control system
    ./helix
    ./impala.nix # WiFi TUI management tool
    ./jujutsu.nix # Git-compatible DVCS that is both simple and powerful
    ./markdown-oxide.nix # Markdown LSP server inspired by Obsidian
    ./nixvim # Configure Neovim with Nix
    ./ollama.nix # Get up and running with large language models locally
    ./pay-respects.nix # Command suggestions, command-not-found and thefuck replacement
    ./rbw.nix # Unofficial Bitwarden CLI for password management
    ./rclone.nix # Sync files and directories to and from major cloud storage
    ./rip.nix # Replacement for rm with focus on safety, ergonomics and performance
    ./sops.nix # Simple and flexible tool for managing secrets
    # ./spotify-player.nix # Terminal-based Spotify client with full feature parity
    ./tealdeer.nix # A very fast implementation of tldr
    ./yazi
  ];

  programs = {
    # cliphist.enable = true; # Wayland clipboard manager
    bottom.enable = true; # A cross-platform graphical process/system monitor
    home-manager.enable = true; # A Nix-based user environment configurator
    nix-index.enable = true; # A files database for nixpkgs
    # comma (nix-index-database) is automatically available via the home module import
  };

  home.packages = with pkgs; [
    # clipboard-jh # Cut, copy, and paste anything, anywhere, all from the terminal
    dua # Tool to conveniently learn about the disk usage of directories
    fclones # Efficient Duplicate File Finder and Remover
    lazyjournal # TUI for journalctl, file system logs, as well as Docker and Podman containers
    lstr # Fast, minimalist directory tree viewer written in Rust
    nix-inspect # Interactive TUI for inspecting nix configs
    ouch # A CLI for easily compressing and decompressing files and directories
    pik # Process Interactive Kill
    procs # A modern replacement for ps
    # quickemu # Quickly create and run virtual machines
    ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
    rm-improved # Replacement for rm
    spotify-player # Terminal spotify player that has feature parity with the official client
    superfile # Pretty fancy and modern terminal file manager
    typst # New markup-based typesetting system that is powerful and easy to learn
    xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
  ];

  services = {
    lorri.enable = true; # Your project's nix-env
  };
}
