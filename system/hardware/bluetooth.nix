{inputs, ...}: {
  imports = [
    "${inputs.impermanence}/nixos.nix"
  ];

  # environment.persistence."/per" = {
  #   hideMounts = true;
  #   directories = [
  #     "/var/lib/bluetooth"
  #   ];
  # };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Powers up the default Bluetooth controller on boot
      settings = {
        General = {
          ControllerMode = "dual"; # Explicitly set controller mode
          Experimental = true; # Show battery charge of bluetooth devices
          KernelExperimental = true; # Enable ISO sockets

          # Modern headsets will generally try to connect using the A2DP profile
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };

  environment.persistence."/per".directories = ["/var/lib/bluetooth"];

  systemd.tmpfiles.rules = [
    "L /var/lib/bluetooth - - - - /per/var/lib/bluetooth"
  ];
}
