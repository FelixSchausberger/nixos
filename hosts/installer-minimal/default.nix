{
  lib,
  pkgs,
  inputs,
  ...
}: let
  # nixos-wizard references pkgs.nixfmt-classic in its postInstall, which was
  # removed from nixpkgs and now throws. Patch the derivation to skip that.
  nixos-wizard-patched = let
    raw = inputs.nixos-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in
    raw.overrideAttrs (_old: {
      postInstall = ''
        wrapProgram $out/bin/nixos-wizard \
          --prefix PATH : ${pkgs.lib.makeBinPath [
          inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
          pkgs.bat
          pkgs.nixfmt-rfc-style
          pkgs.nixfmt
          pkgs.util-linux
          pkgs.gawk
          pkgs.gnugrep
          pkgs.gnused
          pkgs.ntfs3g
        ]}
      '';
    });
in {
  imports = [
    ../installer-shared.nix
  ];

  hostConfig = {
    hostName = "installer-minimal";
    isGui = false;
    wms = [];
  };

  isoShared = {
    hostName = "installer-minimal";
    isoName = "nixos-installer-minimal.iso";
    volumeID = "NIXOS_MIN";
    autoLoginUser = true;
    extraPackages = [
      nixos-wizard-patched
    ];
  };

  # Override schausberger user for ISO (empty password, no sops)
  users.users.schausberger = {
    hashedPasswordFile = lib.mkForce null;
    password = ""; # Empty password for easy ISO login
  };

  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Minimal Installation Environment                       ║
    ║  Fast, lightweight installer for testing                      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    Configuration: /per/etc/nixos

    Installation Steps:
      1. Configure network (if needed): nmtui
      2. Option A - Remote install (recommended for VMs):
         Set root password: passwd
         Get IP: ip addr show
         From dev machine:
           nix run github:nix-community/nixos-anywhere -- \
             --flake .#hostname root@<this-ip>
      3. Option B - Local install from this ISO:
         a. Create GitHub token (required for flake inputs):
            Visit: https://github.com/settings/tokens/new
            Scopes: NONE needed (just for public repo access)
            Expiration: 7 days (temporary)
         b. Set up configuration:
            cp -r /per/etc/nixos /tmp/nixos-config
            cd /tmp/nixos-config
            ln -sf config-installer.nix config.nix
         c. Install with GitHub authentication:
            export NIX_CONFIG="access-tokens = github.com=$YOUR_TOKEN"
            sudo -E nixos-rebuild switch --flake .#hostname
            (Note: -E flag preserves environment)
      4. Reboot into your new system

    Available hosts: desktop, hp-probook-wsl, m920q

    Alternative: Install via SSH from dev machine
      ssh root@<this-ip> and run the same commands

    Note: This is the minimal ISO - essential tools only.
    For full recovery environment, use installer-iso-full.

    Network:
      • SSH enabled with password and key authentication
      • Root password: nixos
      • NetworkManager available: nmtui
      • Find IP: ip addr show

    EOF
  '';
}
