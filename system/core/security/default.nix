{pkgs, ...}: {
  imports = [
    ./sops.nix
    ./ssh.nix
  ];

  security = {
    # Allow wayland lockers to unlock the screen
    pam.services = {
      cthulock.text = "auth include login";
      su = {
        unixAuth = true; # Ensure pam_unix.so is used
      };
    };

    # Userland niceness
    rtkit.enable = true;

    # Don't ask for password for wheel group
    sudo.wheelNeedsPassword = false;

    # Ensure FUSE is configured system-wide
    wrappers.fusermount3 = {
      source = "${pkgs.fuse3}/bin/fusermount3";
      owner = "root";
      group = "root";
      setuid = true;
    };

    # CA certificates for system-wide TLS trust
    pki.installCACerts = true;
  };

  services = {
    printing.browsed.enable = false; # Disable OpenPrinting CUPS vulnerabilities
  };

  # Security-related persistence moved to ../persistence.nix for consolidation
}
