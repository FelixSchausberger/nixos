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

    # Opt new sessions into being shareable through the zellij web server
    # (served via Tailscale Serve on this host). The web server itself is the
    # systemd service modules.system.homelab.zellijWeb.
    zellij.settings.web_sharing = "on";
  };
  # opencode scopes sessions by working directory, and its web UI lists only
  # the project matching the server's CWD (default $HOME). Pinning the shared
  # server to the config repo makes TUI (`oc`) and phone-facing web UI show
  # the same sessions.
  systemd.user.services.opencode-web.Service.WorkingDirectory = "/per/etc/nixos";

  home = {
    shellAliases = {
      just = "just --justfile /per/etc/nixos/justfile --working-directory /per/etc/nixos";
    };

    sessionVariables = {
      VITALS_URL = "http://127.0.0.1:8080";
      EDITOR = "hx";
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
  };

  # Required by some shared modules

  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";
}
