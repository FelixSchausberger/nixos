{
  networking = {
    # Required by zfs.
    hostId = "89b3c408"; # Generate with 'head -c4 /dev/urandom | od -t x4 | cut -c9-16'

    # WiFi configuration
    networkmanager.enable = true;

    # Better compatibility with different networks
    firewall = {
      enable = true;
      allowPing = true;
    };
  };
}
