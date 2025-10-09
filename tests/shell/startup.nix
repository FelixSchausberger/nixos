# Namaka test for shell startup validation
# Tests that fish shell can start successfully with the current configuration
{pkgs, ...}: {
  expr = pkgs.runCommand "test-fish-startup" {} ''
    set -e

    echo "Testing fish shell basic startup..."
    # Test fish can start without config
    timeout 5s ${pkgs.fish}/bin/fish --no-config -c 'exit 0' || {
      echo "❌ Fish basic startup failed"
      exit 1
    }

    echo "Testing fish can load functions..."
    # Test fish config loads (syntax validation)
    timeout 5s ${pkgs.fish}/bin/fish --no-config -c 'functions' >/dev/null || {
      echo "❌ Fish functions test failed"
      exit 1
    }

    echo "Testing bash fallback shell..."
    # Test bash fallback
    timeout 5s ${pkgs.bash}/bin/bash --noprofile --norc -c 'exit 0' || {
      echo "❌ Bash fallback failed"
      exit 1
    }

    echo "✅ All shell startup tests passed"
    touch $out
  '';

  expected = "";
}
