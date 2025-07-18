{
  # config,
  inputs,
  ...
}: {
  imports = [
    "${inputs.impermanence}/nixos.nix"
  ];

  environment.persistence."/per" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };

  networking = {
    # Required by zfs.
    # Generate with 'head -c4 /dev/urandom | od -t x4 | cut -c9-16'
    hostId = "89b3c408";

    # WiFi configuration
    # wireless = {
    #   networks = {
    #     # Pretty-Fly-For-A-WiFi = {
    #     #   psk = config.sops.secrets."wifi/pretty-fly-for-a-wifi".path;
    #     # };

    #     Magenta-766410 = {
    #       psk = config.sops.secrets."wifi/magenta-766410".path;
    #     };

    #     Hochbau-Talstation = {
    #       psk = config.sops.secrets."wifi/hochbau-talstation".path;
    #     };
    #   };
    # };
    networkmanager.enable = true;
    # Enable wireless support
    wireless.enable = false; # Disabled in favor of NetworkManager

    # Better compatibility with different networks
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  # TEMPORARILY DISABLED - SOPS SECRETS CAUSING BUILD FAILURES
  # sops.secrets = {
  #   "wifi/magenta-766410" = {};
  #   "wifi/hochbau-talstation" = {};
  # };

  # environment.etc."NetworkManager/system-connections".source = "/per/etc/NetworkManager/system-connections";
}
