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
