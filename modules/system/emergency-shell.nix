{
  config,
  lib,
  pkgs,
  ...
}: {
  options.system.emergency = {
    enable = lib.mkEnableOption "emergency shell and recovery features";

    enableSystemdEmergencyMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable systemd emergency mode for filesystem mount failures";
    };

    enableInitrdEmergencyAccess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable emergency access during initrd stage";
    };

    shellFallbackTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Timeout in seconds for shell fallback detection";
    };
  };

  config = lib.mkIf config.system.emergency.enable {
    # Enable systemd emergency mode for proper emergency shell access
    systemd.enableEmergencyMode = lib.mkDefault config.system.emergency.enableSystemdEmergencyMode;

    # Enable emergency access during initrd stage
    boot.initrd.systemd.emergencyAccess = config.system.emergency.enableInitrdEmergencyAccess;

    # Simple emergency detection helper for shells
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "emergency-mode-check" ''
        #!/usr/bin/env bash
        # Simple emergency mode detector - checks only systemd emergency state

        if systemctl is-system-running 2>/dev/null | grep -q emergency; then
          echo "emergency"
          exit 0
        else
          echo "normal"
          exit 1
        fi
      '')
    ];

    # Systemd service to monitor and log emergency mode transitions
    systemd.services.emergency-monitor = {
      description = "Monitor emergency mode transitions";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/journalctl --since='1 minute ago' --grep='emergency|rescue' --no-pager || true";
      };
    };

    # Add emergency mode information to issue file
    environment.etc."emergency-help.txt".text = ''
      NixOS Emergency Recovery Help
      =============================

      System Emergency Mode:
      - systemctl emergency         # Enter emergency mode
      - systemctl default           # Exit emergency mode
      - systemctl is-system-running # Check current mode
      - journalctl --grep=emergency # View emergency logs

      Boot Recovery:
      - Add 'systemd.unit=rescue.target' to kernel params for rescue mode
      - Add 'systemd.unit=emergency.target' for emergency mode
      - Add 'init=/bin/bash' for minimal shell (last resort)

      Shell Recovery:
      - bash --noprofile --norc     # Clean bash session
      - fish --no-config            # Clean fish session
      - env -i bash                 # Minimal environment bash
    '';

    # Ensure proper emergency shell in initrd
    boot.initrd.systemd.settings.Manager = {
      DefaultStandardOutput = "tty";
      DefaultStandardError = "tty";
    };
  };
}
