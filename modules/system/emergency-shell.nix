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
  };

  config = lib.mkIf config.system.emergency.enable {
    systemd.enableEmergencyMode = lib.mkDefault config.system.emergency.enableSystemdEmergencyMode;

    boot.initrd.systemd.emergencyAccess = config.system.emergency.enableInitrdEmergencyAccess;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "emergency-mode-check" ''
        if systemctl is-system-running 2>/dev/null | grep -q emergency; then
          echo "emergency"
          exit 0
        else
          echo "normal"
          exit 1
        fi
      '')

      # Minimal shell fallback for WSL when the default shell fails
      (pkgs.writeShellScriptBin "wsl-emergency-shell" ''
        export PATH="/run/current-system/sw/bin:/usr/bin:/bin"
        echo "NixOS-WSL Emergency Recovery Shell"
        echo
        echo "Core tools: /run/current-system/sw/bin"
        echo "Recovery docs: GitHub Wiki - Emergency Recovery"
        echo
        echo "Common recovery tasks:"
        echo "  Fix fish config:    mv ~/.config/fish ~/.config/fish.backup"
        echo "  Disable auto-start: touch ~/.config/fish/EMERGENCY_MODE_ENABLED"
        echo "  Fix PATH:           export PATH=/run/current-system/sw/bin:\$PATH"
        echo "  Test rebuild:       sudo nixos-rebuild test --flake /per/etc/nixos"
        echo
        echo "From Windows: wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell"
        exec /run/current-system/sw/bin/bash --noprofile --norc
      '')
    ];

    environment.etc."emergency-help.txt".text = ''
      NixOS Emergency Recovery Guide
      ================================

      IMMEDIATE RECOVERY (Shell Lockout)

      From Windows PowerShell/CMD:
        wsl.exe --exec /run/current-system/sw/bin/bash --noprofile --norc
        wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell

      From within broken fish shell:
        exec /run/current-system/sw/bin/bash --noprofile --norc

      EMERGENCY ESCAPE HATCHES

      Disable all auto-start features:
        touch ~/.config/fish/EMERGENCY_MODE_ENABLED
        (Remove file to re-enable)

      FISH SHELL RECOVERY

      Restore fish configuration:
        mv ~/.config/fish/config.fish ~/.config/fish/config.fish.broken
        mv ~/.config/fish/config.fish.backup ~/.config/fish/config.fish

      Start fish without config:
        fish --no-config

      Reset fish to safe state:
        rm -rf ~/.config/fish
        mkdir -p ~/.config/fish
        echo "set fish_greeting" > ~/.config/fish/config.fish

      ZELLIJ RECOVERY

      Disable Zellij auto-start temporarily:
        set -e ZELLIJ_AUTO_START

      Fix Zellij configuration:
        mv ~/.config/zellij/config.kdl ~/.config/zellij/config.kdl.backup
        zellij setup --generate-config

      SYSTEM EMERGENCY MODE

      Enter/exit systemd emergency mode:
        systemctl emergency         # Enter emergency mode
        systemctl default           # Exit emergency mode
        systemctl is-system-running # Check current mode
        journalctl --grep=emergency # View emergency logs

      BOOT RECOVERY

      Kernel parameters for recovery:
        systemd.unit=rescue.target    # Rescue mode
        systemd.unit=emergency.target # Emergency mode
        init=/bin/bash                # Minimal shell (last resort)

      PATH NOT SET

      Export PATH manually:
        export PATH="/run/current-system/sw/bin:/usr/bin:/bin"

      NIXOS REBUILD

      Test configuration safely:
        sudo nixos-rebuild test --flake /per/etc/nixos

      Apply configuration:
        sudo nixos-rebuild switch --flake /per/etc/nixos

      Rollback to previous generation:
        sudo nixos-rebuild --rollback switch

      WSL-SPECIFIC RECOVERY

      NixOS-WSL recovery shell:
        wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery

      Restart WSL:
        wsl -t NixOS    # Terminate specific distro
        wsl --shutdown  # Shutdown all distros
    '';

    boot.initrd.systemd.settings.Manager = {
      DefaultStandardOutput = "tty";
      DefaultStandardError = "tty";
    };
  };
}
