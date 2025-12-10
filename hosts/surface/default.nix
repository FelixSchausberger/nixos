# Surface Pro configuration with Stylix theming
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "surface";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports =
    [
      ./disko.nix
      ../shared-gui.nix
      inputs.stylix.nixosModules.stylix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/performance-profiles.nix

      # Surface-specific hardware module
      inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;
    # user and system use defaults from lib/defaults.nix

    # Surface-specific specialisations focused on performance profiles
    specialisations = {
      # Power-saving mode for battery life
      power-saving = {
        wms = null; # Inherit from parent (niri)
        profile = "power-saving";
      };

      # Performance mode when docked/charging
      performance = {
        wms = null; # Inherit from parent (niri)
        profile = "productivity";
      };
    };
  };

  # Surface uses ext4, not ZFS - disable persistence from system/core
  environment.persistence = lib.mkForce {};

  # Stylix theme management using Catppuccin Mocha
  stylix = let
    inherit (inputs.self.lib) fonts;
    catppuccin = inputs.self.lib.catppuccinColors.mocha;
  in {
    enable = true;

    # Use Catppuccin Mocha colors via base16 scheme
    base16Scheme = {
      base00 = catppuccin.base; # Default background
      base01 = catppuccin.mantle; # Lighter background (status bars, line numbers)
      base02 = catppuccin.surface0; # Selection background
      base03 = catppuccin.surface1; # Comments, invisibles
      base04 = catppuccin.surface2; # Dark foreground (status bars)
      base05 = catppuccin.text; # Default foreground
      base06 = catppuccin.subtext1; # Light foreground
      base07 = catppuccin.subtext0; # Light background
      base08 = catppuccin.red; # Variables, XML tags
      base09 = catppuccin.peach; # Integers, booleans
      base0A = catppuccin.yellow; # Classes, search text
      base0B = catppuccin.green; # Strings
      base0C = catppuccin.teal; # Support, regex
      base0D = catppuccin.blue; # Functions, methods
      base0E = catppuccin.mauve; # Keywords, storage
      base0F = catppuccin.flamingo; # Deprecated, embedded
    };

    # Font configuration using centralized fonts
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        inherit (fonts.families.monospace) name;
      };
      sansSerif = {
        package = pkgs.inter;
        inherit (fonts.families.sansSerif) name;
      };
      serif = {
        package = pkgs.merriweather;
        inherit (fonts.families.serif) name;
      };
      sizes = {
        applications = fonts.sizes.normal;
        terminal = fonts.sizes.normal;
        desktop = fonts.sizes.normal;
        popups = fonts.sizes.normal;
      };
    };

    # Cursor theme using centralized configuration
    cursor = {
      package = pkgs.bibata-cursors;
      inherit (fonts.cursor) name;
      inherit (fonts.cursor) size;
    };

    # Enable targets for GUI apps
    targets = {
      # Console/TTY theming
      console.enable = true;

      # GUI applications
      gtk.enable = true;

      # Disable QT theming since we manage it manually via shared-environment.nix
      qt.enable = false;
    };
  };

  # Force stable LTS kernel to avoid Rust compilation issues in newer kernels
  # The nixos-hardware surface module may try to use a newer kernel
  boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages;

  # Override vaapiIntel with enableHybridCodec
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };

  # Configure additional OpenGL packages
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      libva-vdpau-driver
      libvdpau-va-gl
      libcamera # Camera support
      libwacom-surface # Better stylus and touch support
      linux-firmware
      microcode-intel
    ];
  };

  # Surface-specific configurations
  # microsoft-surface = {
  #   ipts.enable = true;
  #   surface-control.enable = true;
  # };

  console.keyMap = "de";
}
