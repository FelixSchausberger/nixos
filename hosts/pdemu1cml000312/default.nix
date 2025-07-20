{pkgs, ...}: let
  hostLib = import ../lib.nix;
  wms = ["hyprland" "gnome"];
in {
  imports =
    [
      ../shared.nix
      ./hardware-configuration.nix
      ../../modules/system/work
      ../../system/nix/work/substituters.nix
    ]
    ++ hostLib.wmModules wms;

  hostConfig = {
    hostName = "pdemu1cml000312";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # Enable container tools
  modules.system.containers.enable = true;

  # Network performance optimizations
  networking = {
    # Disable dhcpcd on ethernet interface to prevent 30s boot delay
    dhcpcd.enable = false;

    # Use NetworkManager for all interfaces (WiFi and ethernet)
    networkmanager.enable = true;

    # Disable unused network interfaces to speed up boot
    # interfaces.enp1s0f0.useDHCP = false;
  };

  # Boot optimizations
  systemd.services = {
    # Don't wait for network-online for faster boot
    "NetworkManager-wait-online".enable = false;

    # Reduce timeout for device detection
    "systemd-udevd".serviceConfig = {
      TimeoutSec = "10s";
    };
  };

  # Hardware configuration
  hardware = {
    # Enable WiFi support
    enableAllFirmware = true;

    # AMD 680M iGPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "laptop";
    };
  };

  # System maintenance and monitoring (work laptop)
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = false; # Disable auto-updates for work stability
    monitoring = {
      enable = true;
      alerts = true;
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Zed editor wrapper to override ZFS daemon conflict
    (pkgs.writeShellScriptBin "zed" ''
      exec ${pkgs.zed-editor}/bin/zeditor "$@"
    '')
  ];

  # Work-specific secrets
  services.sopswarden.secrets = {
    # AWS CLI credentials
    "awscli/id" = "AWS CLI Access Key ID";
    "awscli/key" = "AWS CLI Secret Access Key";

    # GitHub token for Nix API access
    "github/token" = "GitHub Personal Access Token";

    # GitLab token
    "gitlab/token" = "GitLab Personal Access Token";

    # Work-related secrets
    "magazino/email" = "Magazino Work Email";
    "magazino/vault-token" = "Magazino Vault Token";

    # SSH authorized keys
    "ssh/authorized_keys/magazino" = "SSH Authorized Keys Magazino";

    # VPN configuration
    "vpn/auth" = "VPN Authentication";
    "vpn/ca.crt" = "VPN CA Certificate";
    "vpn/client.crt" = "VPN Client Certificate";
    "vpn/key" = "VPN Private Key";
  };
}
