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

    specialisations = {
      niri = {
        wms = ["niri"];
        profile = "default";
        # extraConfig is a module function; pkgs is used for niri/uwsm package references.
        # lib is captured from the outer module scope via lexical scoping.
        extraConfig = {pkgs, ...}: {
          imports = [../../modules/system/wm/niri.nix];

          # Parent config is headless (isGui = false); force GUI mode here.
          hostConfig.isGui = lib.mkForce true;

          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };

          # programs.niri and programs.uwsm are guarded by lib.mkIf (hostConfig.isGui && ...)
          # in niri.nix/session modules. Those guards don't fire in the specialisation context
          # due to _module.args evaluation ordering, so force-enable them here directly.
          programs.niri = {
            enable = lib.mkForce true;
            package = pkgs.niri;
          };
          programs.uwsm = {
            enable = lib.mkForce true;
            waylandCompositors.niri = {
              prettyName = "Niri";
              comment = "Scrollable tiling Wayland compositor";
              binPath = "${pkgs.niri}/bin/niri --session";
            };
          };

          # session/default.nix switches dbus to broker when UWSM is enabled.
          # Changing dbus live is unsafe; keep the running implementation to allow
          # `just activate niri` without a reboot.
          services.dbus.implementation = lib.mkForce "dbus";

          # Intel UHD 630 drivers are already set via mkDefault in parent — no override needed.
          # agetty autologin on tty1: greetd's initial_session is skipped when the user
          # already has active logind sessions (SSH), so getty + fish loginShellInit is used
          # instead. PAM/systemd-logind assigns seat0, granting DRM access for niri.
          services.getty.autologinUser = inputs.self.lib.user;

          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../modules/home/wm/niri
            ../../home/profiles/m920q/niri.nix.specialisation
          ];
        };
      };
    };
  };

  # x86_64-linux; set here since hardware-configuration.nix is generated post-install
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ThinkCentre M920q: Intel i7-8700T, Intel UHD 630 iGPU
  # modesetting covers headless operation; full graphics stack added by niri specialisation
  services.xserver.videoDrivers = lib.mkDefault ["modesetting" "intel"];

  # Unique ZFS host identifier — required per machine, must not match any other host
  networking.hostId = lib.mkForce "b580701b";

  # ZFS ARC: 8GB cap (50% of 16GB RAM, suitable for NAS read caching)
  boot.kernelParams = lib.mkAfter ["zfs.zfs_arc_max=8589934592"];

  # vkms provides a virtual display adapter for the niri specialisation's headless remote desktop.
  # Loaded unconditionally so `just activate niri` works without a reboot.
  boot.kernelModules = ["vkms"];

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
      udpGROInterface = "eno1";
    };

    # Requires real domain names pointing to 116.204.198.109 — enable after DNS is configured
    caddy.enable = false;

    rustdesk = {
      enable = true;
      # Tailscale IP — advertised by hbbs so remote clients know where to reach hbbr
      relayAddress = "100.105.37.12";
    };

    # Requires grafana secrets
    monitoring.enable = true;

    ssh.enable = true;
  };
}
