{
  lib,
  config,
  ...
}: let
  isIntel = config.hardware.cpu.intel.updateMicrocode or false;
in {
  options.hardware.profiles.intelCpu = {
    enable = lib.mkEnableOption "Intel CPU thermal management and optimizations";
  };

  config = lib.mkIf config.hardware.profiles.intelCpu.enable {
    services.thermald.enable = isIntel;
  };
}
