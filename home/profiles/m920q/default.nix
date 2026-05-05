{
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Server home profile: TUI-only, SSH-accessible dev environment.
  # No WM configuration — GUI is handled by the niri system specialisation.

  features = {
    development = {
      enable = true;
      # Rust devshells work out of the box via direnv; no global toolchain needed
      languages = [
        "nix"
        "rust"
      ];
    };
  };

  programs = {
    fish.enable = true;
    starship.enable = true;
    zoxide.enable = true;
    git.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  home = {
    shellAliases = {
      just = "just --justfile /per/etc/nixos/justfile --working-directory /per/etc/nixos";
    };

    sessionVariables = {
      VITALS_URL = "http://127.0.0.1:8080";
      # SSH logins attach to this named zellij session (see fish auto-start logic).
      ZELLIJ_SSH_SESSION = "homelab";
    };

    packages = with pkgs; [
      # System monitoring
      btop
      ncdu
      duf
      iotop
      nethogs
      lsof
      smartmontools

      # Power/CPU monitoring
      linuxPackages.turbostat # Per-CPU frequency and C-state statistics

      # Network tools
      nmap
      dig
      wget
      curl

      # File sharing management
      samba # provides smbclient, smbpasswd, net

      # Remote coding from phone via SSH
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Vitals health monitoring CLI
      inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.cli
    ];

    sessionVariables = {
      EDITOR = "hx";
    };
  };

  # Required by some shared modules

  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";
}
