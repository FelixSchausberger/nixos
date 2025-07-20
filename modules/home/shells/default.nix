{config, ...}: {
  imports = [
    ./bash.nix # GNU Bourne-Again Shell, the de facto standard shell on Linux (for interactive use)
    ./fish # Smart and user-friendly command line shell
    ./starship.nix # A minimal, blazing fast, and extremely customizable prompt
    # ./zellij.nix # Terminal multiplexer with modern features
    ./zoxide.nix # A fast cd command that learns your habits
  ];

  home.shellAliases = {
    build = "nix build -L";
    cp = "cp -rpv";
    list-errors = "journalctl -p err -b --output=cat | sort | uniq -c | sort -nr";
    merge = "rsync -avhu --progress";
    nixinfo = "nix-shell -p nix-info --run 'nix-info -m'";
    pls = "sudo";
    repair = "sudo nix-store --verify --check-contents --repair";
    rip = "rip --graveyard /per/home/${config.home.username}/.local/share/graveyard";
  };
}
