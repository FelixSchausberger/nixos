# Test emergency recovery procedures for WSL
{pkgs, ...}: {
  test = {
    name = "emergency-recovery-wsl";
    description = "Validate WSL emergency recovery mechanisms";

    testScript = ''
      # Test 1: Emergency utilities exist
      machine.succeed("command -v emergency-mode-check")
      machine.succeed("command -v wsl-emergency-shell")
      machine.succeed("command -v emergency-status")

      # Test 2: Emergency help file exists
      machine.succeed("test -f /etc/emergency-help.txt")
      machine.succeed("cat /etc/emergency-help.txt | grep -q 'NixOS Emergency Recovery Guide'")

      # Test 3: Emergency mode check returns correct status
      machine.fail("emergency-mode-check")  # Should exit 1 when not in emergency mode

      # Test 4: Fish emergency mode bypass doesn't exit shell
      machine.succeed("su - schausberger -c 'touch ~/.config/fish/EMERGENCY_MODE_ENABLED'")
      # Should be able to run commands with emergency mode enabled
      machine.succeed("su - schausberger -c 'fish -c \"echo test\"'")
      machine.succeed("su - schausberger -c 'rm ~/.config/fish/EMERGENCY_MODE_ENABLED'")

      # Test 5: PATH auto-initialization in fish
      # Simulate incomplete PATH
      result = machine.succeed("su - schausberger -c 'env -i HOME=/home/schausberger fish -c \"echo \\$PATH\"'")
      # PATH should be automatically fixed
      assert "/run/current-system/sw/bin" in result, f"PATH not properly initialized: {result}"

      # Test 6: Core utilities available after PATH fix
      machine.succeed("su - schausberger -c 'fish -c \"command -v ls\"'")
      machine.succeed("su - schausberger -c 'fish -c \"command -v sort\"'")
      machine.succeed("su - schausberger -c 'fish -c \"command -v grep\"'")

      # Test 7: Zellij pre-flight check function exists
      machine.succeed("su - schausberger -c 'fish -c \"type __zellij_preflight_check\"'")

      # Test 8: Emergency functions available in fish
      machine.succeed("su - schausberger -c 'fish -c \"type emergency-status\"'")
      machine.succeed("su - schausberger -c 'fish -c \"type emergency-reset\"'")

      # Test 9: Emergency user exists for recovery
      machine.succeed("id emergency")
      machine.succeed("getent passwd emergency | grep -q 'bash'")

      # Test 10: Emergency user can access bash
      machine.succeed("su - emergency -c 'echo test'")
    '';

    nodes.machine = {
      imports = [
        ../../hosts/hp-probook-wsl
      ];
    };
  };
}
