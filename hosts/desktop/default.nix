{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../helpers.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hostData.${hostName};
in {
  imports =
    [
      ./disko.nix
      ../shared-gui.nix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/performance-profiles.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    wm = hostInfo.wms;
    # user and system use defaults from lib/defaults.nix

    # Define specialisations for this host
    specialisations = {
      # Single WM configurations for testing
      gnome-only = {
        wm = ["gnome"];
        profile = "productivity";
      };

      hyprland-only = {
        wm = ["hyprland"];
        profile = "default";
      };

      hyprland-gaming = {
        wm = ["hyprland"];
        profile = "gaming";
      };

      niri-only = {
        wm = ["niri"];
        profile = "default";
      };

      niri-portable = {
        wm = ["niri"];
        profile = "power-saving";
      };

      # Build-optimized configuration for compilation workloads
      build-optimized = {
        wm = ["hyprland"];
        profile = "productivity";
      };
    };
  };

  # Stylix theme management using shared Catppuccin Mocha module
  modules.system.stylix-catppuccin = {
    enable = true;
    # Use custom font packages from inputs for desktop
    fontPackages = {
      monospace = inputs.nixpkgs.legacyPackages.x86_64-linux.nerd-fonts.jetbrains-mono;
      sansSerif = inputs.nixpkgs.legacyPackages.x86_64-linux.inter;
      serif = inputs.nixpkgs.legacyPackages.x86_64-linux.merriweather;
    };
    cursorPackage = inputs.nixpkgs.legacyPackages.x86_64-linux.bibata-cursors;
  };

  # Hardware configuration
  hardware = {
    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;

    # AMD RX 6700XT GPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
    };
  };

  # Nix build optimizations for desktop (Ryzen 5 5600: 6C/12T)
  nix.settings = {
    max-jobs = lib.mkForce 6; # Parallel derivation builds (one per physical core)
    cores = lib.mkForce 12; # Parallel jobs within each build (all threads)

    # Build performance
    keep-outputs = lib.mkForce false; # Don't keep build outputs (saves disk)
    keep-derivations = lib.mkForce false; # Don't keep .drv files
    auto-optimise-store = lib.mkForce true; # Hardlink identical files
  };

  # Use tmpfs for Nix builds (desktop has 16GB RAM)
  # Significantly speeds up compilation with RAM-backed builds
  systemd.services.nix-daemon.environment = {
    TMPDIR = "/tmp/nix-build";
  };
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root - -"
  ];

  # System specialisations for testing different configurations
  # These allow switching between configurations without full rebuilds
  # Usage: sudo nixos-rebuild switch --flake . --specialisation <name>
  #
  # Note: Specialisations are currently disabled due to conflicts when forcing
  # single WM configurations while inheriting multi-WM parent config.
  # The issue is that WM modules set conflicting options (e.g., PAM settings)
  # and simply using mkForce on hostConfig.wm isn't sufficient to disable
  # the other WM modules' settings.
  #
  # To properly implement single-WM specialisations, we would need to:
  # 1. Not use inheritParentConfig = true
  # 2. Manually re-import all base system configs
  # 3. Import only the desired WM module
  #
  # For now, to test individual WMs, temporarily modify hostConfig.wm in
  # hosts/desktop/default.nix directly.

  # specialisation = {
  #   # GNOME-only configuration
  #   gnome-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["gnome"];
  #     };
  #   };
  #
  #   # Hyprland-only configuration
  #   hyprland-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["hyprland"];
  #     };
  #   };
  #
  #   # Niri-only configuration
  #   niri-only = {
  #     inheritParentConfig = true;
  #     configuration = {
  #       hostConfig.wm = inputs.nixpkgs.lib.mkForce ["niri"];
  #     };
  #   };
  # };
}
