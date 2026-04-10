{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "m920q";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports =
    [
      ./disko.nix
      ../shared-tui.nix
      ../boot-zfs.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/homelab
      inputs.stylix.nixosModules.stylix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/nixpkgs-overlays.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui wms;
    # Server workload: use performance governor, no power-saving
    performanceProfile = "productivity";

    # niri-gui specialisation deferred until after initial install:
    # niri must be built from source on the live ISO (binary cache unavailable there),
    # which fails with EMFILE in the sandbox. Re-enable after first boot:
    #   sudo nixos-rebuild switch --flake /per/etc/nixos#m920q
    # Then activate with: sudo nixos-specialisation niri-gui activate
  };

  # x86_64-linux; set here since hardware-configuration.nix is generated post-install
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ThinkCentre M920q: Intel i7-8700T, Intel UHD 630 iGPU
  # modesetting driver covers headless operation; full graphics stack added by niri-gui
  services.xserver.videoDrivers = lib.mkDefault ["modesetting" "intel"];

  # Unique ZFS host identifier — required per machine, must not match any other host
  networking.hostId = lib.mkForce "b580701b";

  # ZFS ARC: 8GB cap (50% of 16GB RAM, suitable for NAS read caching)
  boot.kernelParams = lib.mkAfter ["zfs.zfs_arc_max=8589934592"];

  fileSystems."/per".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  # Disable services not applicable to server hardware
  services = {
    # fwupd: useful for real hardware (BIOS, NIC firmware); keep enabled
    # geoclue2: location services have no purpose on a headless server
    geoclue2.enable = lib.mkForce false;
  };

  # Host-specific sops secrets — expanded when monitoring/tailscale-auth are enabled

  modules.system = {
    stylix-catppuccin.enable = true;
    containers.enable = true;
    maintenance = {
      enable = true;
      # Manual updates preferred for a production server
      autoUpdate.enable = false;
      monitoring = {
        enable = true;
        alerts = true;
      };
    };
  };

  modules.system.homelab = {
    adguardhome.enable = true;

    # Requires data disk (dpool) — enable after 2TB drive is installed
    samba.enable = false;
    immich.enable = false;

    tailscale = {
      enable = true;
      # authKeyFile omitted — run `sudo tailscale up` after first boot to authenticate
      advertiseRoutes = ["192.168.178.0/24"];
    };

    # Requires real domain names pointing to 116.204.198.109 — enable after DNS is configured
    caddy.enable = false;

    rustdesk.enable = true;

    # Requires grafana secrets — enable after adding grafana/{admin-password,secret-key} to secrets.yaml
    monitoring.enable = false;

    ssh.enable = true;
  };
}
