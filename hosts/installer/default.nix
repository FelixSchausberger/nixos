{pkgs, ...}: {
  imports = [
    ../installer-shared.nix
    ../../modules/system/recovery-tools.nix
  ];

  hostConfig = {
    hostName = "installer";
    isGui = false;
    wms = [];
  };

  isoShared = {
    hostName = "installer";
    isoName = "nixos-installer-full.iso";
    volumeID = "NIXOS_FULL";
    extraPackages = with pkgs; [
      # Network diagnostics
      dnsutils
      inetutils
      whois

      # Installation tools
      nh
      screen
    ];
  };

  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Installation Environment (Full)                        ║
    ║  Complete recovery and installation tools                     ║
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

    Note: This is the full ISO with GUI and comprehensive recovery tools.
    For lightweight testing, use installer-iso-minimal.

    Network:
      • SSH enabled with password and key authentication
      • Root password: nixos
      • NetworkManager available: nmtui
      • Find IP: ip addr show

    EOF
  '';
}
