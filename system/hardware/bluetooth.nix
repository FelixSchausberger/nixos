{inputs, ...}: {
  imports = [
    "${inputs.impermanence}/nixos.nix"
  ];

  environment.persistence."/per" = {
    hideMounts = true;
    directories = [
      "/var/lib/bluetooth"
    ];
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Powers up the default Bluetooth controller on boot
      settings = {
        General = {
          # Show battery charge of bluetooth devices
          Experimental = true;
          # Modern headsets will generally try to connect using the A2DP profile
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L /var/lib/bluetooth - - - - /per/var/lib/bluetooth"
  ];
}
