{
  pkgs,
  lib,
  config,
  ...
}: let
  safeNotifySend = import ../../../home/lib/safe-notify-send.nix {inherit pkgs config;};
  safeNotifyBin = "${safeNotifySend}/bin/safe-notify-send";
in {
  imports = [
    ./helix # Post-modern modal text editor
    ./neovim.nix # Neovim with basic configuration (replaces nixvim to avoid tree-sitter-ada issue)
    ./yazi # Blazing fast terminal file manager written in Rust, based on async I/O
    ./bluetui.nix # Bluetooth TUI management tool (kept separate due to config)
    ./ai-assistants # AI coding assistants (Claude Code, OpenCode) with shared MCP servers and behaviors
    ./fd.nix # A simple, fast and user-friendly alternative to find
    ./git.nix # Distributed version control system
    ./jujutsu.nix # Git-compatible DVCS that is both simple and powerful
    ./markdown-oxide.nix # Markdown LSP server inspired by Obsidian
    ./monitoring.nix # Modern system monitoring and performance tools
    ./nh.nix # Yet another Nix CLI helper - Modern replacement for nixos-rebuild
    ./ollama.nix # Get up and running with large language models locally
    ./rbw.nix # Unofficial Bitwarden CLI for password management
    ./rclone.nix # Sync files and directories to and from major cloud storage
    ./sops.nix # Simple and flexible tool for managing secrets
    # ./spotify-player.nix # Terminal-based Spotify client with full feature parity
    ./typix.nix # Typst: A markup-based typesetting system
    ./zellij.nix # Terminal multiplexer with modern features
  ];

  programs = {
    # cliphist.enable = true; # Wayland clipboard manager
    home-manager.enable = true; # A Nix-based user environment configurator
    nix-index.enable = true; # A files database for nixpkgs

    # Enable modern monitoring tools (includes bottom configuration)
    monitoring.enable = true;

    pay-respects = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      options = ["--alias" "f"];
    };
  };

  home.packages = with pkgs; [
    basalt # Modern shell written in Rust with a focus on portability and performance
    cacert # CA certificates for TLS connections
    # clipboard-jh # Cut, copy, and paste anything, anywhere, all from the terminal
    fclones # Efficient Duplicate File Finder and Remover
    lan-mouse # Software KVM switch for sharing mouse and keyboard over network
    lazyjournal # TUI for journalctl, file system logs, as well as Docker and Podman containers
    lstr # Fast, minimalist directory tree viewer written in Rust
    impala # WiFi TUI management tool
    iwd # Modern WiFi daemon (needed by impala)
    nix-diff # Tool to explain why two Nix derivations differ
    nix-inspect # Interactive TUI for inspecting nix configs
    nix-tree # Interactively browse the dependency graph of Nix derivations
    ouch # A CLI for easily compressing and decompressing files and directories
    outfieldr # Fast TLDR client in Zig (34x faster than tealdeer, no certificate issues)
    pik # Process Interactive Kill
    # quickemu # Quickly create and run virtual machines
    ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
    rm-improved # Replacement for rm (replaces both rip.nix and provides better rm)
    scooter # Interactive find and replace in the terminal
    # superfile # Pretty fancy and modern terminal file manager
    systemd-manager-tui # Program for managing systemd services through a tui
    typst # New markup-based typesetting system that is powerful and easy to learn
    xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
  ];

  services = {
    lorri.enable = true; # Your project's nix-env
  };

  home.sessionPath = lib.mkBefore ["$HOME/.local/bin"];

  home.file.".local/bin/notify-send" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      exec ${safeNotifyBin} "$@"
    '';
  };

  # Shell health check activation script
  # Runs after packages are linked to ensure they're available in PATH
  home.activation.shellHealthCheck = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run echo "🏥 Running shell configuration health check..."

    # Set PATH to include new generation packages
    export PATH="$newGenPath/home-path/bin:$PATH"

    # Run health check with proper PATH - make it non-fatal (warnings only)
    if run ${pkgs.fish}/bin/fish /per/etc/nixos/tools/scripts/shell-health-check.fish; then
      run echo "✅ Shell health check passed"
    else
      run echo "⚠️  Shell health check found issues (non-fatal during activation)"
      run echo "   Review warnings above - system will still activate"
    fi
  '';
}
