{
  # Import the shared boot-zfs.nix configuration
  imports = [../boot-zfs.nix];

  # Thinkpad-specific disk encryption configuration
  boot.initrd.luks.devices = {
    "luks-rpool" = {
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL4512HBLU-00BL7_S67VNF0TA81898-part2";
      preLVM = true;
    };
  };

  # Thinkpad-specific swap configuration
  swapDevices = [
    {
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL4512HBLU-00BL7_S67VNF0TA81898-part3";
      randomEncryption = {
        enable = true;
        allowDiscards = true;
      };
    }
  ];
}
