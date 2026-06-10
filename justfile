# Justfile for NixOS and Niri development workflows
# Use `just --list` to see all available recipes

# Default recipe displays available commands
default:
    @just --list

# === NIRI HOT-RELOAD WORKFLOWS ===

# Build Niri config and validate syntax without system rebuild
niri-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    HOSTNAME=$(hostname)
    USERNAME=$(whoami)
    echo "Building home configuration for $USERNAME@$HOSTNAME..."

    # Build just the home-manager configuration
    nix build .#nixosConfigurations.$HOSTNAME.config.home-manager.users.$USERNAME.home.activationPackage \
        --out-link /tmp/niri-home-config

    # Extract and validate the Niri config
    NIRI_CONFIG="/tmp/niri-home-config/home-files/.config/niri/config.kdl"
    if [ -f "$NIRI_CONFIG" ]; then
        echo "Validating Niri config..."
        niri validate -c "$NIRI_CONFIG"
        echo "✓ Niri config is valid"
    else
        echo "✗ Error: Niri config not found at $NIRI_CONFIG"
        exit 1
    fi

# Build, validate, and hot-reload Niri config to running instance
niri-reload:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate first
    just niri-validate

    # Activate the new home-manager generation
    echo "Activating new home-manager generation..."
    /tmp/niri-home-config/activate

    # Reload Niri config
    echo "Reloading Niri..."
    niri msg config-reload
    echo "✓ Niri config reloaded successfully"

# Watch for Niri config changes and auto-validate
niri-watch:
    #!/usr/bin/env bash
    echo "Watching modules/home/wm/niri/ for changes..."
    echo "Press Ctrl+C to stop"
    echo ""
    while true; do
        inotifywait -q -e modify,create,delete -r modules/home/wm/niri/ && {
            echo ""
            echo "[$(date '+%H:%M:%S')] Change detected, validating..."
            just niri-validate && echo "" || echo ""
        }
    done

# Build just the Niri package from nixpkgs
niri-rebuild:
    nix build nixpkgs#niri

# === CODE QUALITY ===

# Simplify staged changes via Claude Code CLI
simplify:
    git diff --cached | claude -p "Review the following diff and suggest simplifications: reduce nesting, remove debug artifacts, convert nested ternaries to if/else, remove obvious comments. Preserve all functionality and conditional logging. Output only the simplified file contents for files that need changes." --output-format text

# Format all Nix files
fmt:
    nix fmt

# Run all pre-commit hooks
check:
    prek run --all-files

# Run snapshot tests
test:
    namaka check

# Review snapshot test changes
review:
    namaka review

# Full validation: format, hooks, and tests
validate: fmt check test

# === SYSTEM MANAGEMENT ===

# Test system configuration without making it permanent (SAFE - recommended for testing)
system-test:
    sudo nixos-rebuild test --flake .

# Build home-manager configuration without activation
home-build:
    #!/usr/bin/env bash
    HOSTNAME=$(hostname)
    USERNAME=$(whoami)
    nix build .#nixosConfigurations.$HOSTNAME.config.home-manager.users.$USERNAME.home.activationPackage \
        --out-link result-home

# Switch system specialisation temporarily (reverts on next reboot)
# Uses /nix/var/nix/profiles/system (the latest deployed generation) so that:
# - Newly rebuilt specialisations take effect without a reboot
# - headless <-> specialisation cycles work without redeploying in between
#   just activate niri -> just activate headless -> just activate niri -> ...
# Usage: just activate list | headless | <name>
activate NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    PROFILE=/nix/var/nix/profiles/system
    MODE_FILE=/run/$(hostname)-current-mode
    HM_SERVICE="home-manager-$(whoami).service"
    USERNAME=$(whoami)

    wait_for_nix_daemon() {
        timeout 30 bash -c 'until nix-daemon --version >/dev/null 2>&1; do sleep 0.5; done' 2>/dev/null || true
    }

    graceful_niri_exit() {
        sudo -u "$USERNAME" DISPLAY= WAYLAND_DISPLAY= XDG_RUNTIME_DIR=/run/user/1000 niri msg quit 2>/dev/null || true
        timeout 5 bash -c "while systemctl --user -M ${USERNAME}@ is-active niri.service 2>/dev/null; do sleep 0.5; done" || true
    }

    case "{{NAME}}" in
        list)
            echo "headless"
            ls "$PROFILE/specialisation/" 2>/dev/null || true
            ;;
        headless)
            wait_for_nix_daemon
            if systemctl --user -M "${USERNAME}@" is-active niri.service 2>/dev/null; then
                graceful_niri_exit
            fi
            sudo "$PROFILE/bin/switch-to-configuration" test
            echo "headless" | sudo tee "$MODE_FILE" > /dev/null
            sudo systemctl restart "$HM_SERVICE"
            sudo systemctl restart getty@tty1.service
            ;;
        *)
            wait_for_nix_daemon
            sudo "$PROFILE/specialisation/{{NAME}}/bin/switch-to-configuration" test
            echo "{{NAME}}" | sudo tee "$MODE_FILE" > /dev/null
            sudo systemctl restart "$HM_SERVICE"
            if [ "{{NAME}}" = "niri" ]; then
                sudo systemctl start bluetooth.service
                sudo systemctl restart getty@tty1.service
            fi
            ;;
    esac

# Shorthand aliases for common specialisation switches
gui:
    just activate niri

tty:
    just activate headless

# Desktop mode aliases
home:
    just activate home

away:
    just activate headless

desktop-status:
    @cat /run/desktop-current-mode 2>/dev/null || echo "unknown"

# === QUALITY MONITORING ===

# Calculate test coverage
coverage:
    @echo "Calculating test coverage..."
    @bash tools/scripts/calculate-coverage.sh

# Detect unused modules
check-unused:
    @echo "Checking for unused modules..."
    @bash tools/scripts/detect-unused-modules.sh

# Profile evaluation time
profile-eval:
    @echo "Profiling evaluation time..."
    @bash tools/scripts/profile-evaluation.sh

# Profile evaluation with flamegraph visualization for identifying bottlenecks
# Output: HOST-profile.svg — open in browser or upload to https://speedscope.app
# In speedscope: use Sandwich view, filter by "derivationStrict"
profile-flamegraph HOST="desktop":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Generating flamegraph for: {{HOST}}"
    nix eval --no-eval-cache \
        ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel" \
        --option eval-profiler flamegraph \
        --option eval-profile-file "{{HOST}}-profile"
    nix shell nixpkgs#flamegraph -c flamegraph.pl "{{HOST}}-profile" > "{{HOST}}-profile.svg"
    echo "Flamegraph: {{HOST}}-profile.svg"

# Check closure sizes
check-closures:
    @echo "Checking closure sizes..."
    @bash tools/scripts/check-closure-size.sh

# Generate quality dashboard
dashboard:
    @echo "Generating quality dashboard..."
    @bash tools/scripts/generate-quality-dashboard.sh

# Run all quality checks
quality-check: coverage check-unused profile-eval check-closures
    @echo "All quality checks complete"

# === FLAKE MANAGEMENT ===

# Update flake inputs
update:
    nix flake update

# Update a specific flake input
update-input INPUT:
    nix flake lock --update-input {{INPUT}}

# Check flake for errors
flake-check:
    nix flake check

# Show flake info
flake-info:
    nix flake show
