{pkgs, ...}: {
  imports = [
    ./bat.nix # A cat clone with syntax highlighting and Git integration
    ./direnv.nix # A shell extension that manages your environment
    ./eza.nix # A modern, maintained replacement for ls
    ./fd.nix # A simple, fast and user-friendly alternative to find
    ./fzf.nix # A command-line fuzzy finder written in Go
    ./gammastep.nix # Screen color temperature manager
    ./git.nix # Distributed version control system
    ./helix
    ./jujutsu.nix # Git-compatible DVCS that is both simple and powerful
    ./nix.nix # Nix tooling
    ./rclone.nix # Sync files and directories to and from major cloud storage
    ./rip.nix # Replacement for rm with focus on safety, ergonomics and performance
    ./sops.nix # Simple and flexible tool for managing secrets
    ./tealdeer.nix # A very fast implementation of tldr
    ./thefuck.nix # Magnificent app which corrects your previous console command
    ./yazi
  ];

  programs = {
    # cliphist.enable = true; # Wayland clipboard manager
    bottom.enable = true; # A cross-platform graphical process/system monitor
    home-manager.enable = true; # A Nix-based user environment configurator
    nix-index.enable = true; # A files database for nixpkgs
  };

  home.packages = with pkgs; [
    # clipboard-jh # Cut, copy, and paste anything, anywhere, all from the terminal
    lazyjournal # TUI for journalctl, file system logs, as well as Docker and Podman containers
    mdcat # Cat for markdown
    ouch # A CLI for easily compressing and decompressing files and directories
    pik # Process Interactive Kill
    procs # A modern replacement for ps
    # quickemu # Quickly create and run virtual machines
    ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
    rm-improved # Replacement for rm
    superfile # Pretty fancy and modern terminal file manager
  ];

  services = {
    lorri.enable = true; # Your project's nix-env
  };
}
