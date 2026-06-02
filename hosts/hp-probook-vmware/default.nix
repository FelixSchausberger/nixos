# VMware workstation profile for the HP ProBook environment.
# Mirrors physical-host defaults where possible while using VM-specific graphics and firmware behavior.
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
      ./disko.nix
      ../shared-gui.nix
      inputs.stylix.nixosModules.stylix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/nixpkgs-overlays.nix # Build fixes for package dependencies
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;
    # user and system use defaults from lib/defaults.nix

    # Enable auto-login for VM convenience
    autoLogin = {
      enable = true;
      inherit (inputs.self.lib) user;
    };
  };

  modules.system.stylix-catppuccin.enable = true;

  # Hardware configuration
  # Disable AMD GPU profile for VM (uses VMware graphics)
  hardware.profiles.amdGpu.enable = lib.mkForce false;

  # Override video drivers for VMware and disable smartd for VM (VMware virtual disks don't support SMART)
  services = {
    xserver = {
      videoDrivers = lib.mkForce [
        "vmware"
        "modesetting"
      ];
      xkb = {
        layout = "de";
        variant = "";
      };
    };
    smartd.enable = lib.mkForce false;
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
        ntfyUrl = "http://m920q:2586/homelab-alerts";
      };
    };
  };

  # ZFS with impermanence (matching physical hosts)
  # The VM now uses the same ZFS structure as desktop/surface for consistency
  # Disko creates the filesystems, but we need to set neededForBoot for impermanence

  # Required for impermanence: filesystems must be mounted early in boot
  fileSystems."/per".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;
}
