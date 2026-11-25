_: {
  # Device state persists to /per/var/lib/bluetooth (see system/core/persistence.nix).
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Powers up the default Bluetooth controller on boot
      settings = {
        General = {
          ControllerMode = "dual"; # Explicitly set controller mode
          Experimental = true; # Show battery charge of bluetooth devices
          KernelExperimental = true; # Enable ISO sockets
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L /var/lib/bluetooth - - - - /per/var/lib/bluetooth"
  ];
}
