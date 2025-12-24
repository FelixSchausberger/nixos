{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "hp-probook-vmware";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports =
    [
      ./disko/disko.nix
      ../shared-gui.nix
      inputs.stylix.nixosModules.stylix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    wm = hostInfo.wms;
    # user and system use defaults from lib/defaults.nix

    # Enable auto-login for VM convenience
    autoLogin = {
      enable = true;
      user = "schausberger";
    };
  };

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
        package = inputs.nixpkgs.legacyPackages.x86_64-linux.nerd-fonts.jetbrains-mono;
        inherit (fonts.families.monospace) name;
      };
      sansSerif = {
        package = inputs.nixpkgs.legacyPackages.x86_64-linux.inter;
        inherit (fonts.families.sansSerif) name;
      };
      serif = {
        package = inputs.nixpkgs.legacyPackages.x86_64-linux.merriweather;
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
      package = inputs.nixpkgs.legacyPackages.x86_64-linux.bibata-cursors;
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

  # Hardware configuration
  # Disable AMD GPU profile for VM (uses VMware graphics)
  hardware.profiles.amdGpu.enable = lib.mkForce false;

  # Override video drivers for VMware
  services.xserver.videoDrivers = lib.mkForce ["vmware" "modesetting"];

  # Keyboard layout configuration
  services.xserver.xkb = {
    layout = "eu";
    variant = "";
  };

  # Sync console keyboard layout with X11 configuration
  console.useXkbConfig = true;

  # System modules configuration
  modules.system = {
    containers.enable = true;
    maintenance = {
      enable = true;
      autoUpdate.enable = true;
      monitoring = {
        enable = true;
        alerts = true;
      };
    };
  };

  # Disable smartd for VM (VMware virtual disks don't support SMART)
  services.smartd.enable = lib.mkForce false;

  # ZFS with impermanence (matching physical hosts)
  # The VM now uses the same ZFS structure as desktop/surface for consistency
  # Disko creates the filesystems, but we need to set neededForBoot for impermanence

  # Required for impermanence: /per must be mounted early in boot
  fileSystems."/per".neededForBoot = true;

  # Disable systemd-initrd for VM compatibility with ZFS
  # The systemd-initrd has a known issue with ZFS path resolution (assertion error)
  # Use traditional dracut-based initrd instead for reliable ZFS import
  boot.initrd.systemd.enable = lib.mkForce false;
}
