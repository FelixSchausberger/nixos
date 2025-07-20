{pkgs, ...}: let
  hostLib = import ../lib.nix;
  wms = ["gnome"];
in {
  imports =
    [
      ../shared.nix
      ./boot-zfs.nix
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

  # Essential kernel parameters
  boot = {
    kernelModules = ["amdgpu" "kvm-amd"];
    kernelParams = [
      "amdgpu.dc=1"
      "amdgpu.sg_display=0"
      "amdgpu.dpm=1"
      "amdgpu.modeset=1"
      "amd_pstate=active"
    ];
    initrd.kernelModules = ["amdgpu"];
  };

  # AMD 680M iGPU configuration
  hardware = {
    enableRedistributableFirmware = true;

    # Enable WiFi support
    enableAllFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;

      # Use bleeding-edge Mesa drivers
      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      extraPackages = with pkgs; [
        libva
        vulkan-loader
        vulkan-validation-layers
        amdvlk
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        libva
        amdvlk
      ];
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vulkan-tools
    glxinfo
  ];

  # Work-specific secrets
  services.sopswarden.secrets = {
    # AWS CLI credentials
    "awscli/id" = "AWS CLI Access Key ID";
    "awscli/key" = "AWS CLI Secret Access Key";

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
