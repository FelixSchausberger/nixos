# Emergency recovery integration for broken shell/session states.
# Exposes minimal fallback commands and systemd emergency-mode wiring.
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

    deadmanAutoRecover = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When systemd lands in emergency/rescue mode, start a countdown that
        reboots the machine after a grace period. Combined with systemd-boot
        boot counting, this gives unattended self-recovery: a wedged boot is
        rolled back to the last-known-good generation instead of idling in an
        emergency shell that locks out SSH/Tailscale/network. A human reaching
        the console during the grace window can stop the countdown.
      '';
    };
  };

  config = let
    isWsl = config ? wsl && (config.wsl.enable or false);
  in
    lib.mkIf config.system.emergency.enable {
      systemd.enableEmergencyMode = lib.mkDefault config.system.emergency.enableSystemdEmergencyMode;

      boot.initrd.systemd.emergencyAccess = config.system.emergency.enableInitrdEmergencyAccess;

      environment.systemPackages =
        [
          (pkgs.writeShellScriptBin "emergency-mode-check" ''
            if systemctl is-system-running 2>/dev/null | grep -q emergency; then
              echo "emergency"
              exit 0
            else
              echo "normal"
              exit 1
            fi
          '')
        ]
        ++ lib.optionals isWsl [
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

      environment.etc."emergency-help.txt".text = let
        wslSection = lib.optionalString isWsl ''

          WSL-SPECIFIC RECOVERY

          NixOS-WSL recovery shell:
            wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery

          Restart WSL:
            wsl -t NixOS    # Terminate specific distro
            wsl --shutdown  # Shutdown all distros
        '';
        wslInstructions = lib.optionalString isWsl ''

          From Windows PowerShell/CMD:
            wsl.exe --exec /run/current-system/sw/bin/bash --noprofile --norc
            wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell
        '';
      in ''
        NixOS Emergency Recovery Guide
        ================================

        IMMEDIATE RECOVERY (Shell Lockout)
        ${wslInstructions}
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

        SSH auto-attach to Zellij is disabled while emergency mode is active
        (see "SYSTEM EMERGENCY MODE" below).

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
          sudo nixos-rebuild --rollback switch${wslSection}
      '';

      boot.initrd.systemd.settings.Manager = {
        DefaultStandardOutput = "tty";
        DefaultStandardError = "tty";
      };

      # Deadman switch: only active in emergency/rescue mode. Starts a long
      # countdown; if no human stops it before it elapses, the machine reboots
      # so systemd-boot boot counting rolls back to the previous generation.
      # A human at the console can cancel it (systemctl stop emergency-deadman).
      systemd.services.emergency-deadman = lib.mkIf config.system.emergency.deadmanAutoRecover {
        description = "Reboot after grace period in emergency/rescue mode";
        wantedBy = ["emergency.target" "rescue.target"];
        after = ["emergency.target" "rescue.target"];
        unitConfig.RequiresMountsFor = "/run";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.writeShellScript "emergency-deadman" ''
            echo "Emergency/rescue mode reached. Reboot in 1200s unless cancelled (systemctl stop emergency-deadman)." >&2
            sleep 1200
            echo "Deadman expired; rebooting to trigger boot-counting rollback." >&2
            ${pkgs.systemd}/bin/systemctl reboot
          ''}";
        };
      };
    };
}
