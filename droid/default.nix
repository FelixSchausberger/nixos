# Nix-on-Droid configuration for the phone. This is NOT NixOS: it configures
# the proot-based Nix-on-Droid environment inside the com.termux.nix Android
# app (no root, no systemd, no Wayland). Scope is the day-to-day
# homelab-from-phone workflow - remote access to the hosts plus the usual TUI
# tooling - so the phone terminal is reproducible like the rest of the fleet.
# Android apps are not managed here; install those from F-Droid. The user
# environment (shell, ssh, git) is Home Manager's job; see droid/home.nix.
{
  inputs,
  hostConfig,
  lib,
  pkgs,
  ...
}: {
  # Bump only after reading the nix-on-droid changelog.
  system.stateVersion = "24.05";

  # Home Manager owns the user environment (shell prompt, ssh config, git
  # identity). The profile is self-contained (droid/home.nix) because the
  # fleet's modules/home is NixOS- and WSL-coupled; only the portable shell
  # leaves are reused. inputs/hostConfig arrive via flake-parts/droid.nix.
  home-manager = {
    config = ./home.nix;
    useGlobalPkgs = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = {inherit inputs hostConfig;};
  };

  # The phone is the slowest machine in the fleet: never build locally what the
  # cache can serve, and keep flakes on so the config can follow this repo.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    fallback = true
  '';

  environment = {
    # nix-on-droid hardcodes /etc/resolv.conf to public resolvers, which cannot
    # resolve the tailnet's MagicDNS names (*.ts.net is not published publicly).
    # Ask Tailscale's resolver first so `ssh m920q` resolves to the tailnet
    # address instead of forcing the raw 100.x IP; keep public DNS as a fallback
    # for when Tailscale is down. mkForce: the networking module owns this file.
    etc."resolv.conf".text = lib.mkForce ''
      nameserver 100.100.100.100
      nameserver 1.1.1.1
      nameserver 8.8.8.8
    '';

    # Back up unmanaged files in /etc instead of aborting activation: a
    # bootstrap can leave files behind that a later generation no longer owns.
    etcBackupExtension = ".bak";

    # Homelab-from-phone toolset, mirroring the m920q TUI profile: ssh/mosh to
    # the hosts, zellij for session attach, fish/starship for the shell,
    # jj/git/nvim for the repo. Kept in environment.packages (not
    # home.packages) so the login environment stays usable even if Home
    # Manager activation ever fails.
    packages = with pkgs; [
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
  };

  user.shell = "${pkgs.fish}/bin/fish";
  time.timeZone = "Europe/Vienna";
}
