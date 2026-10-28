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
      ../../modules/system/tailscale.nix

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

    zellijAutoAttach.sessionName = "surface";

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

  modules.system.stylix-catppuccin.enable = true;

  modules.system.maintenance = {
    enable = true;
    monitoring = {
      enable = true;
      alerts = true;
      ntfyUrl = "http://${inputs.self.lib.hosts.m920q.tailnetIp}:2586/homelab-alerts";
    };
  };

  # Pull-based GitOps: converge to main automatically, alert on downgrades
  modules.system.comin = {
    enable = true;
    alertNtfyUrl = "http://${inputs.self.lib.hosts.m920q.tailnetIp}:2586/homelab-alerts";
  };

  # ZFS requires a per-host hostId; the shared default in system/network.nix
  # must never repeat across ZFS hosts (pool import ownership conflicts).
  networking.hostId = lib.mkForce "4903fe7e";

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

  # nixos-hardware surface module and performance-profiles.nix both set
  # services.tlp.enable via lib.mkDefault (priority 1000), causing a merge conflict
  # in the power-saving specialisation. Surface manages power via power-profiles-daemon.
  services.tlp.enable = lib.mkForce false;

  # Tailscale for fixed reachability across networks (MagicDNS)
  modules.system.homelab.tailscale.enable = true;
}
