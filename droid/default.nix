# Nix-on-Droid configuration for the phone. This is NOT NixOS: it configures
# the proot-based Nix-on-Droid environment inside the com.termux.nix Android
# app (no root, no systemd, no Wayland). Scope is the day-to-day
# homelab-from-phone workflow - remote access to the hosts plus the usual TUI
# tooling - so the phone terminal is reproducible like the rest of the fleet.
# Android apps are not managed here; install those from F-Droid.
{pkgs, ...}: {
  # Bump only after reading the nix-on-droid changelog.
  system.stateVersion = "24.05";

  # The phone is the slowest machine in the fleet: never build locally what the
  # cache can serve, and keep flakes on so the config can follow this repo.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    fallback = true
  '';

  # Homelab-from-phone toolset, mirroring the m920q TUI profile: ssh/mosh to the
  # hosts, zellij for session attach, fish/starship for the shell, jj/git/nvim
  # for the repo.
  environment.packages = with pkgs; [
    fish
    starship
    zoxide
    direnv
    openssh
    mosh
    zellij
    git
    jujutsu
    neovim
    curl
    wget
    ripgrep
    fd
    jq
    tree
    htop
    unzip
    which
    procps
  ];

  user.shell = "${pkgs.fish}/bin/fish";
  time.timeZone = "Europe/Vienna";
}
