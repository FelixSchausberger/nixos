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
    sessionVariables = {
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

      # Network tools
      nmap
      dig
      wget
      curl

      # File sharing management
      samba # provides smbclient, smbpasswd, net

      # Remote coding from phone via SSH
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    sessionVariables = {
      EDITOR = "hx";
    };
  };

  # Required by some shared modules

  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";
}
