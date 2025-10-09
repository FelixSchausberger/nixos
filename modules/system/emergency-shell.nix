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

      # WSL Emergency Shell Wrapper - provides minimal shell when fish fails
      (pkgs.writeShellScriptBin "wsl-emergency-shell" ''
        #!/usr/bin/env bash
        # NixOS-WSL Emergency Recovery Shell
        # This script provides a minimal shell when the default shell fails

        export PATH="/run/current-system/sw/bin:/usr/bin:/bin"

        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║        NixOS-WSL Emergency Recovery Shell                     ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "📍 Core tools available at: /run/current-system/sw/bin"
        echo "📍 Recovery documentation: See GitHub Wiki - Emergency Recovery"
        echo ""
        echo "🔧 Common Recovery Tasks:"
        echo "   • Fix fish config:     mv ~/.config/fish ~/.config/fish.backup"
        echo "   • Disable auto-start:  touch ~/.config/fish/EMERGENCY_MODE_ENABLED"
        echo "   • Fix PATH:            export PATH=/run/current-system/sw/bin:\$PATH"
        echo "   • Rebuild system:      sudo nixos-rebuild switch --flake /per/etc/nixos"
        echo "   • View emergency help: emergency-help"
        echo ""
        echo "🚀 To access this shell from Windows:"
        echo "   wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell"
        echo ""

        exec /run/current-system/sw/bin/bash --noprofile --norc
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
      ╔══════════════════════════════════════════════════════════════════╗
      ║             NixOS Emergency Recovery Guide                       ║
      ╚══════════════════════════════════════════════════════════════════╝

      === IMMEDIATE RECOVERY (Shell Lockout) ===

      From Windows PowerShell/CMD:
        wsl.exe --exec /run/current-system/sw/bin/bash --noprofile --norc
        wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell

      From within broken fish shell:
        exec /run/current-system/sw/bin/bash --noprofile --norc

      === EMERGENCY ESCAPE HATCHES ===

      Disable all auto-start features:
        touch ~/.config/fish/EMERGENCY_MODE_ENABLED
        (Remove file to re-enable)

      Enable system-wide emergency mode:
        touch /tmp/.nixos-emergency-mode
        (Remove file to disable)

      === FISH SHELL RECOVERY ===

      Restore fish configuration:
        mv ~/.config/fish/config.fish ~/.config/fish/config.fish.broken
        mv ~/.config/fish/config.fish.backup ~/.config/fish/config.fish

      Start fish without config:
        fish --no-config

      Reset fish to safe state:
        rm -rf ~/.config/fish
        mkdir -p ~/.config/fish
        echo "set fish_greeting" > ~/.config/fish/config.fish

      === ZELLIJ RECOVERY ===

      Disable Zellij auto-start temporarily:
        set -e ZELLIJ_AUTO_START

      Fix Zellij configuration:
        mv ~/.config/zellij/config.kdl ~/.config/zellij/config.kdl.backup
        zellij setup --generate-config

      === SYSTEM EMERGENCY MODE ===

      Enter/exit systemd emergency mode:
        systemctl emergency         # Enter emergency mode
        systemctl default           # Exit emergency mode
        systemctl is-system-running # Check current mode
        journalctl --grep=emergency # View emergency logs

      === BOOT RECOVERY ===

      Kernel parameters for recovery:
        systemd.unit=rescue.target    # Rescue mode
        systemd.unit=emergency.target # Emergency mode
        init=/bin/bash                # Minimal shell (last resort)

      === PATH NOT SET ===

      Export PATH manually:
        export PATH="/run/current-system/sw/bin:/usr/bin:/bin"

      Core tools location:
        /run/current-system/sw/bin/   # All NixOS system tools

      === NIXOS REBUILD ===

      Test configuration safely:
        sudo nixos-rebuild test --flake /per/etc/nixos

      Apply configuration:
        sudo nixos-rebuild switch --flake /per/etc/nixos

      Rollback to previous generation:
        sudo nixos-rebuild --rollback switch

      === WSL-SPECIFIC RECOVERY ===

      NixOS-WSL recovery shell:
        wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery

      Restart WSL:
        wsl -t NixOS    # Terminate specific distro
        wsl --shutdown  # Shutdown all distros

      === ADDITIONAL RESOURCES ===

      NixOS-WSL Documentation:
        https://nix-community.github.io/NixOS-WSL/troubleshooting/recovery-shell.html

      Zellij Integration Guide:
        https://zellij.dev/documentation/integration.html

      Emergency Commands:
        emergency-status         # Check emergency mode status
        emergency-help           # Display this help
        wsl-emergency-shell      # Launch emergency shell (WSL only)
    '';

    # Ensure proper emergency shell in initrd
    boot.initrd.systemd.settings.Manager = {
      DefaultStandardOutput = "tty";
      DefaultStandardError = "tty";
    };
  };
}
