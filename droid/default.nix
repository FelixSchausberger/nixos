# Nix-on-Droid configuration for the phone. This is NOT NixOS: it configures
# the proot-based Nix-on-Droid environment inside the com.termux.nix Android
# app (no root, no systemd, no Wayland). Scope is the day-to-day
# homelab-from-phone workflow - remote access to the hosts plus the usual TUI
# tooling - so the phone terminal is reproducible like the rest of the fleet.
# Android apps are not managed here; install those from F-Droid. The user
# environment (shell, ssh, git) is Home Manager's job; see droid/home.nix.
{
  config,
  inputs,
  hostConfig,
  lib,
  pkgs,
  ...
}: let
  # SSH into the phone, so the tailnet reaches it like any other host instead
  # of only working phone-to-homelab. nix-on-droid has no service manager, so
  # activation creates the authorized keys and a host key once, and sshd runs
  # in the foreground via `sshd-start`. Android reserves ports below 1024 for
  # root, and the login account is the app's single user.
  sshdPort = 8022;
  sshdDirectory = "${config.user.home}/sshd";
  sshdTmpDirectory = "${config.user.home}/sshd-tmp";

  sshdConfig = pkgs.writeText "sshd_config" ''
    HostKey ${sshdDirectory}/ssh_host_ed25519_key
    Port ${toString sshdPort}
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    Subsystem sftp internal-sftp
  '';

  # The same key list the NixOS hosts authorize, so any fleet device reaches
  # the phone without a second source of truth.
  authorizedKeys = pkgs.writeText "authorized_keys" (
    lib.concatStringsSep "\n" inputs.self.lib.sshKeys.authorizedKeys + "\n"
  );

  # Without a wake lock Android suspends the app and the listening socket dies
  # with it; the lock is released when this foreground sshd exits.
  sshdStart = pkgs.writeScriptBin "sshd-start" ''
    #!${pkgs.runtimeShell}
    if command -v termux-wake-lock >/dev/null 2>&1; then
      termux-wake-lock
    fi
    echo "Starting sshd on port ${toString sshdPort}"
    exec ${pkgs.openssh}/bin/sshd -f "${sshdDirectory}/sshd_config" -D
  '';
in {
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
      sshdStart
    ];
  };

  # sshd-start needs the app to hold a wake lock, which is what this command
  # does; the Android app implements it, so it costs nothing to enable.
  android-integration.termux-wake-lock.enable = true;

  # Runs at every `nix-on-droid switch`. The host key is kept once generated, so
  # clients do not see a changed key on the next switch.
  build.activation.sshd = ''
    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
    $DRY_RUN_CMD chmod $VERBOSE_ARG 700 "${config.user.home}/.ssh"
    $DRY_RUN_CMD cp ${authorizedKeys} "${config.user.home}/.ssh/authorized_keys"
    $DRY_RUN_CMD chmod $VERBOSE_ARG 600 "${config.user.home}/.ssh/authorized_keys"

    if [[ ! -d "${sshdDirectory}" ]]; then
      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshdTmpDirectory}"
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshdTmpDirectory}"
      $VERBOSE_ECHO "Generating sshd host key..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f "${sshdTmpDirectory}/ssh_host_ed25519_key"
      $VERBOSE_ECHO "Writing sshd_config..."
      $DRY_RUN_CMD cp ${sshdConfig} "${sshdTmpDirectory}/sshd_config"
      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshdTmpDirectory}" "${sshdDirectory}"
    fi
  '';

  user.shell = "${pkgs.fish}/bin/fish";
  time.timeZone = "Europe/Vienna";
}
