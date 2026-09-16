# Portable recovery ISO: a TUI-first live USB image with ZFS support and the
# disk-recovery tool suite. Built as packages.installer-iso-portable.
#
# This is deliberately not a nixosConfiguration: it boots a live squashfs
# environment, has no persistent root, and is never converged by comin. The
# deployed fleet lives in nixosConfigurations (see hosts/default.nix).
{lib, ...}: {
  imports = [
    ../installer-shared.nix
    ../../modules/system/recovery-tools.nix
  ];

  hostConfig = {
    hostName = "portable";
    isGui = false;
    wms = [];
  };

  isoShared = {
    hostName = "portable";
    isoName = "nixos-portable.iso";
    volumeID = "NIXOS_PORTABLE";
    autoLoginUser = true;
  };

  # Override schausberger user for ISO (empty password, no sops)
  users.users.schausberger = {
    hashedPasswordFile = lib.mkForce null;
    password = "";
  };

  system.activationScripts.portableWelcome = ''
    cat > /etc/issue << 'EOF'

    NixOS Portable Recovery Environment
    TUI-only live image with ZFS and disk-recovery tooling.

    Configuration: /per/etc/nixos
    Deployed hosts: desktop, hp-probook-wsl, m920q

    EOF
  '';
}
