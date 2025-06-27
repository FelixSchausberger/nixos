{pkgs, ...}: {
  imports = [
    ./claude-code.nix # An agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
    ./bat.nix # A cat clone with syntax highlighting and Git integration
    ./direnv.nix # A shell extension that manages your environment
    ./eza.nix # A modern, maintained replacement for ls
    ./fd.nix # A simple, fast and user-friendly alternative to find
    ./fzf.nix # A command-line fuzzy finder written in Go
    ./gammastep.nix # Screen color temperature manager
    ./git.nix # Distributed version control system
    ./helix
    ./jujutsu.nix # Git-compatible DVCS that is both simple and powerful
    ./nixai.nix # Ai based nix help system from the command line
    ./nixvim # Configure Neovim with Nix
    # ./neovim.nix # Vim text editor fork focused on extensibility and agility
    ./ollama.nix # Get up and running with large language models locally
    ./pay-respects.nix # Command suggestions, command-not-found and thefuck replacement
    ./rclone.nix # Sync files and directories to and from major cloud storage
    ./rip.nix # Replacement for rm with focus on safety, ergonomics and performance
    ./sops.nix # Simple and flexible tool for managing secrets
    ./tealdeer.nix # A very fast implementation of tldr
    ./yazi
  ];

  programs = {
    # cliphist.enable = true; # Wayland clipboard manager
    bottom.enable = true; # A cross-platform graphical process/system monitor
    home-manager.enable = true; # A Nix-based user environment configurator
    nix-index.enable = true; # A files database for nixpkgs
  };

  # Nix tooling
  # home.packages = with pkgs; [
  #   alejandra
  #   deadnix
  #   statix
  # ];

  home.packages = with pkgs; [
    # clipboard-jh # Cut, copy, and paste anything, anywhere, all from the terminal
    lazyjournal # TUI for journalctl, file system logs, as well as Docker and Podman containers
    ouch # A CLI for easily compressing and decompressing files and directories
    pik # Process Interactive Kill
    procs # A modern replacement for ps
    # quickemu # Quickly create and run virtual machines
    ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
    rm-improved # Replacement for rm
    superfile # Pretty fancy and modern terminal file manager
    tree # Command to produce a depth indented directory listing
    typst # New markup-based typesetting system that is powerful and easy to learn
    xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
  ];

  services = {
    lorri.enable = true; # Your project's nix-env
  };
}
