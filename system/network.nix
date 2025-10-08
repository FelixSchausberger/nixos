{
  networking = {
    # Required by zfs.
    hostId = "89b3c408"; # Generate with 'head -c4 /dev/urandom | od -t x4 | cut -c9-16'

    # WiFi configuration with IWD support
    networkmanager = {
      enable = true;
      wifi.backend = "iwd"; # Use IWD as WiFi backend for NetworkManager
    };
    wireless.iwd.enable = true; # Enable IWD for impala WiFi management tool

    # Better compatibility with different networks
    firewall = {
      enable = true;
      allowPing = true;
    };
  };
}
