{
  lib,
  pkgs,
  hostConfig,
  ...
}: {
  config = lib.mkIf hostConfig.isGui {
    # Runtime performance profile switching via systemd targets
    # Replaces boot-time specialisations for performance profiles

    systemd.targets = {
      gaming-mode = {
        description = "Gaming Performance Mode";
        wants = ["gamemode.service"];
        after = ["multi-user.target"];
      };

      power-saving-mode = {
        description = "Power Saving Mode";
        wants = ["tlp.service" "thermald.service"];
        after = ["multi-user.target"];
      };

      productivity-mode = {
        description = "Productivity Mode (Balanced)";
        after = ["multi-user.target"];
      };
    };

    # Helper script for easy switching
    environment.systemPackages = [
      (pkgs.writeScriptBin "set-performance-mode" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        MODE="''${1:-}"

        if [ -z "$MODE" ]; then
          echo "Usage: set-performance-mode {gaming|power-saving|productivity}"
          echo ""
          echo "Modes:"
          echo "  gaming        - High performance (CPU performance governor, gamemode)"
          echo "  power-saving  - Battery optimization (CPU powersave governor, TLP)"
          echo "  productivity  - Balanced (CPU schedutil governor)"
          exit 1
        fi

        case "$MODE" in
          gaming)
            echo "Switching to Gaming mode (high performance)..."
            systemctl isolate gaming-mode.target
            echo "Gaming mode activated"
            ;;
          power-saving)
            echo "Switching to Power Saving mode (battery optimization)..."
            systemctl isolate power-saving-mode.target
            echo "Power Saving mode activated"
            ;;
          productivity)
            echo "Switching to Productivity mode (balanced)..."
            systemctl isolate productivity-mode.target
            echo "Productivity mode activated"
            ;;
          *)
            echo "Error: Unknown mode '$MODE'"
            echo "Valid modes: gaming, power-saving, productivity"
            exit 1
            ;;
        esac
      '')
    ];

    # Enable gamemode for gaming profile
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
        cpu = {
          park_cores = "no";
          pin_policy = "prefer-physical";
        };
      };
    };

    # Enable TLP for power-saving profile
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        RUNTIME_PM_ON_AC = "auto";
        RUNTIME_PM_ON_BAT = "auto";
      };
    };

    # Thermald already enabled in WM modules, ensure it's available
    services.thermald.enable = true;
  };
}
