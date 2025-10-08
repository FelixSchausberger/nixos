#!/usr/bin/env bash
# Claude Code Rebuild Prevention Hook
# This hook prevents Claude from automatically running system rebuild commands
# and reminds Claude to ask the user for permission first.

set -euo pipefail

# Define prohibited rebuild commands (permanent changes only)
PROHIBITED_COMMANDS=(
    "sudo nixos-rebuild switch"
    "nixos-rebuild switch"
    "sudo nixos-rebuild boot"
    "nixos-rebuild boot"
    "nh os switch"
    "nh os boot"
    "deploy"
    "sudo deploy"
    "home-manager switch"
    "sudo home-manager switch"
)

# Define allowed test commands (temporary, safe testing)
ALLOWED_TEST_COMMANDS=(
    "sudo nixos-rebuild test"
    "nixos-rebuild test"
    "nh os test"
)

# Function to check if command contains test commands (which are allowed)
contains_allowed_test_command() {
    local content="$1"
    for cmd in "${ALLOWED_TEST_COMMANDS[@]}"; do
        if echo "$content" | grep -q "$cmd"; then
            return 0  # Found allowed test command
        fi
    done
    return 1  # No test command found
}

# Function to check if command contains prohibited rebuild patterns
contains_prohibited_command() {
    local content="$1"

    # First check if it's an allowed test command
    if contains_allowed_test_command "$content"; then
        return 1  # Test commands are allowed
    fi

    # Then check for prohibited commands
    for cmd in "${PROHIBITED_COMMANDS[@]}"; do
        if echo "$content" | grep -q "$cmd"; then
            return 0  # Found prohibited command
        fi
    done
    return 1  # No prohibited command found
}

# Check if input contains prohibited commands
if [ $# -gt 0 ]; then
    input_content="$*"
elif [ ! -t 0 ]; then
    input_content=$(cat)
else
    input_content=""
fi

# If prohibited command detected, provide guidance
if contains_prohibited_command "$input_content"; then
    echo "🚫 REBUILD PREVENTION ACTIVATED"
    echo
    echo "Claude Code has detected that you're attempting to run a PERMANENT system rebuild command."
    echo "According to your configuration guidelines, Claude should:"
    echo
    echo "1. ❌ NEVER automatically run PERMANENT rebuild commands (switch/boot/deploy)"
    echo "2. ✅ ALLOW temporary test commands (nixos-rebuild test, nh os test)"
    echo "3. ✅ INFORM the user when a rebuild is necessary"
    echo "4. ✅ WAIT for explicit user confirmation"
    echo "5. ✅ SUGGEST the appropriate rebuild command"
    echo
    echo "Detected prohibited command pattern in:"
    echo "  $input_content"
    echo
    echo "ALLOWED TEST COMMANDS (temporary, no bootloader changes):"
    echo "  - sudo nixos-rebuild test --flake ."
    echo "  - nixos-rebuild test --flake ."
    echo "  - nh os test"
    echo
    echo "PROHIBITED COMMANDS (permanent changes):"
    echo "  - sudo nixos-rebuild switch (makes changes permanent)"
    echo "  - nh os switch (makes changes permanent)"
    echo "  - deploy (makes changes permanent)"
    echo
    echo "Instead of running permanent commands automatically, Claude should:"
    echo "  - Explain what changes require a rebuild"
    echo "  - Recommend testing first with 'nixos-rebuild test'"
    echo "  - Ask the user to run permanent commands manually"
    echo
    echo "Example proper response:"
    echo '  "I'"'"'ve made changes that require a system rebuild."'
    echo '  "You can test them safely with: sudo nixos-rebuild test --flake ."'
    echo '  "If everything works, apply permanently with: sudo nixos-rebuild switch --flake ."'
    echo
    exit 1
fi

# If we get here, no prohibited commands were detected
exit 0