{inputs, ...}: {
  # Base configuration for Desktop host and specialisations
  # This module contains all shared configuration except WM modules and specialisation definitions
  # Note: disko.nix is NOT imported here as it's not needed in specialisations
  imports = [
    ../shared-gui.nix
    inputs.stylix.nixosModules.stylix
    ../../modules/system/stylix-catppuccin.nix
    ../../modules/system/performance-profiles.nix
  ];

  modules.system.stylix-catppuccin.enable = true;

  # Note: Hardware-specific configuration (keyboard, GPU profiles) is set in
  # the main Desktop configuration, not in base-config.nix, as specialisations
  # don't need hardware reconfiguration.

  # Note: System maintenance and monitoring is set in the main Desktop
  # configuration, not in base-config.nix, as specialisations inherit the
  # parent's systemd services.

  # Nix build optimizations for desktop (Ryzen 5 5600: 6C/12T)
  nix.settings = {
    max-jobs = 6; # Parallel derivation builds (one per physical core)
    cores = 12; # Parallel jobs within each build (all threads)

    # Build performance
    keep-outputs = false; # Don't keep build outputs (saves disk)
    keep-derivations = false; # Don't keep .drv files
    auto-optimise-store = true; # Hardlink identical files
  };

  # Use tmpfs for Nix builds (desktop has 16GB RAM)
  # Significantly speeds up compilation with RAM-backed builds
  systemd.services.nix-daemon.environment = {
    TMPDIR = "/tmp/nix-build";
  };
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root - -"
  ];
}
