_: {
  # Bluetooth persistence moved to system/core/persistence.nix for consolidation

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
