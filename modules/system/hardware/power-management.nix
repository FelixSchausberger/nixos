# Power profile for always-on hosts where low idle power and predictable wake behavior matter.
# Combines CPU policy, thermal control, Wake-on-LAN, and LED suppression defaults.
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.hardware.profiles.powerManagement;
  isIntel = config.hardware.cpu.intel.updateMicrocode or false;
in {
  options.hardware.profiles.powerManagement = {
    enable = lib.mkEnableOption "power management for 24/7 homelab servers (auto-cpufreq, powertop, WoL, LED suppression)";

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "Wired ethernet interface for Wake-on-LAN";
    };

    lanMacAddress = lib.mkOption {
      type = lib.types.str;
      description = "Permanent MAC address of the LAN interface, used to match the WoL udev .link file";
    };

    suppressLeds = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable front panel LEDs to reduce light/noise in bedroom";
    };

    intelCpuThermals = lib.mkOption {
      type = lib.types.bool;
      default = true;
      # thermald >= 2.5.12 exits on non-mobile ACPI platform profiles
      # (upstream intel/thermal_daemon#562), so desktop hosts must opt out.
      description = "Enable thermald on Intel systems for sustained thermal control";
    };
  };

  config = lib.mkIf cfg.enable {
    # auto-cpufreq applies a governor and an energy-performance preference per
    # power source. Its config schema is [charger] and [battery], and the AC
    # branch ("charger") is the one an always-on host always runs in. A section
    # under any other name is ignored, and the tool then falls back to its
    # performance-on-AC default, which keeps idle clocks and voltage high and
    # defeats the efficiency intent of the profiles above.
    services.auto-cpufreq = {
      enable = true;
      settings = {
        charger = {
          governor = "powersave";
          energy_performance_preference = "power";
          turbo = "auto";
        };
        battery = {
          governor = "powersave";
          energy_performance_preference = "power";
          turbo = "off";
        };
      };
    };

    # Enable runtime power tuning defaults.
    powerManagement.powertop.enable = lib.mkDefault true;

    # Keep thermal throttling policy active for long-running workloads.
    services.thermald.enable = lib.mkForce (cfg.intelCpuThermals && isIntel);

    boot.kernelParams = [
      # Let cpufreq-based tools manage frequency policy.
      "intel_pstate=passive"

      # Limit deep idle states for predictable wake latency.
      "processor.max_cstate=6"

      # Keep intel_idle aligned with the global C-state cap.
      "intel_idle.max_cstate=6"
    ];

    # Allow waking the host via magic packet. net_setup_link applies this at
    # every udev device-add event, so arming survives clean shutdowns, networkd
    # restarts, and power-button force-offs, unlike a boot-time ethtool service.
    # The device is matched by permanent MAC and the name is pinned: firmware
    # naming data (ID_NET_NAME_ONBOARD) proved unreliable across boots on this
    # hardware, and a rename would silently break the Name= match in the
    # .network file. A matching .link file replaces 99-default.link, so the
    # default MACAddressPolicy is carried over.
    systemd.network.links."10-wol-${cfg.lanInterface}" = {
      matchConfig.PermanentMACAddress = cfg.lanMacAddress;
      linkConfig = {
        Name = cfg.lanInterface;
        MACAddressPolicy = "persistent";
        WakeOnLan = "magic";
      };
    };

    # Disable chassis LED triggers for quieter bedroom operation.
    systemd.tmpfiles.rules = lib.optionals cfg.suppressLeds [
      "w /sys/class/leds/*/trigger - - - - none"
    ];

    environment.systemPackages = with pkgs; [
      powertop
      ethtool
      intel-gpu-tools
    ];
  };
}
