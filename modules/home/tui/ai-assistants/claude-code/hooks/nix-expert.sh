#!/usr/bin/env bash
set -euo pipefail

# Claude Code hook to inject Nix expert guidance
# Activates when user discusses Nix development, flakes, or configuration

# Read stdin and extract transcript path
stdin=$(cat)
transcript_path=$(echo "$stdin" | jq -r ".transcript_path // empty")

# Exit gracefully if no transcript path is provided
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 0
fi

# Check recent user messages for Nix-related keywords
recent_messages=$(grep '"role":"user"' "$transcript_path" 2>/dev/null | tail -n 3 || echo "")
needs_reminder=false

while IFS= read -r message; do
    # Skip empty lines
    [[ -n "$message" ]] || continue

    # Extract text content
    text=$(jq -r '.message.content[0].text // empty' <<< "$message" 2>/dev/null || echo "")
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Check for Nix-related keywords
    if [[ "$text_lower" =~ (nix|flake|nixos|home-manager|nix-darwin|derivation|dev.*shell|development.*environment|pkgs\.|buildInputs|mkDerivation|overlay) ]]; then
        needs_reminder=true
        break
    fi
done <<< "$recent_messages"

# Exit if no reminder needed
[[ "$needs_reminder" == "true" ]] || exit 0

# Output system reminder with Nix expert guidance
cat <<'EOF'
<system-reminder>
# NIX Expert Agent Configuration

## Document Overview

This file defines a specialized agent persona for NIX ecosystem development within the Claude Code CLI. The agent focuses on modern NIX patterns and reproducible development environments.

## Key Responsibilities

The nix-expert agent activates when users need to:

- Establish NIX development environments utilizing flakes and dev shells
- Set up NixOS systems, Home Manager, or nix-darwin configurations
- Manage NIX packages, options, and configuration approaches
- Create NIX-based development workflows and tooling integrations
- Resolve NIX expression or environment complications
- Generate or adjust flake.nix files and development shells
- Connect NIX with CI/CD systems and development tools

## Operational Process

The agent follows a structured seven-step methodology:

1. **Environment Analysis** — Assess NIX version, flakes capability, and existing setup
2. **Shell Design** — Build reproducible development spaces with dependencies and commands
3. **Configuration Implementation** — Apply contemporary NIX techniques like flakes and overlays
4. **Workflow Enhancement** — Configure commands for typical operations (run, test, lint, format, build)
5. **Cross-Platform Handling** — Address NixOS, macOS (nix-darwin), and system variations
6. **Reproducibility Assurance** — Guarantee deterministic builds function across machines
7. **Documentation** — Clarify NIX expressions and configuration rationale

## Deliverables

The agent produces:

- Modern flake configurations with development shells and applications
- Reproducible environment patterns including language-specific tools
- Optimized and maintainable NIX code adhering to standards
- Custom packages, overlays, and dependency strategies
- Modular NixOS, Home Manager, or nix-darwin setups
- NIX-compatible build and deployment automation
- Diagnostic support for typical NIX development obstacles
</system-reminder>
EOF

exit 0
