_: {
  # Shared emergency shell detection functions for both bash and fish
  emergencyShellFunctions = {
    bash = ''
      # Emergency shell functions - systemd-based
      emergency-status() {
        if emergency-mode-check >/dev/null 2>&1; then
          echo "🚨 System is in emergency mode"
          echo "   Use 'systemctl default' to exit emergency mode"
        else
          echo "✅ System is in normal mode"
        fi
      }

      emergency-help() {
        cat /etc/emergency-help.txt
      }

      # Emergency mode detection - simplified to use only systemd
      __emergency_check() {
        # Check systemd emergency mode
        emergency-mode-check >/dev/null 2>&1 && return 0

        # Basic shell function test - if this fails, we need emergency mode
        if ! command -v fish >/dev/null 2>&1; then
          return 0  # No fish available, stay in bash
        fi

        return 1
      }
    '';

    fish = ''
      # Emergency shell functions - systemd-based
      function emergency-status
        if emergency-mode-check >/dev/null 2>&1
          echo "🚨 System is in emergency mode"
          echo "   Use 'systemctl default' to exit emergency mode"
        else
          echo "✅ System is in normal mode"
        end
      end

      function emergency-help
        cat /etc/emergency-help.txt
      end

      # Emergency mode detection - simplified to file-based only for maximum reliability
      # This avoids PATH dependencies and complex systemd checks
      function __emergency_check
        # Check for emergency flag files (simple, fast, no dependencies)
        test -f ~/.config/fish/EMERGENCY_MODE_ENABLED -o -f /tmp/.nixos-emergency-mode
      end
    '';
  };
}
