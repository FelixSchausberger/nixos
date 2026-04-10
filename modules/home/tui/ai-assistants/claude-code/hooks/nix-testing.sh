#!/usr/bin/env bash
set -euo pipefail

# Claude Code hook to inject Nix testing best practices
# Activates when user discusses derivations, packages, or testing

# Read stdin and extract transcript path
stdin=$(cat)
transcript_path=$(echo "$stdin" | jq -r ".transcript_path // empty")

# Exit gracefully if no transcript path is provided
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 0
fi

# Check recent user messages for testing/package-related keywords
recent_messages=$(grep '"role":"user"' "$transcript_path" 2>/dev/null | tail -n 3 || echo "")
needs_reminder=false

while IFS= read -r message; do
    # Skip empty lines
    [[ -n "$message" ]] || continue

    # Extract text content
    text=$(jq -r '.message.content[0].text // empty' <<< "$message" 2>/dev/null || echo "")
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Check for package/testing keywords
    if [[ "$text_lower" =~ (derivation|mkDerivation|package|buildPhase|checkPhase|installCheckPhase|passthru.*test|meta\.|doCheck|test.*nix|nix.*test) ]]; then
        needs_reminder=true
        break
    fi
done <<< "$recent_messages"

# Exit if no reminder needed
[[ "$needs_reminder" == "true" ]] || exit 0

# Output system reminder with Nix testing best practices
cat <<'EOF'
<system-reminder>
---
description: Nix Testing and Quality Assurance
globs: *.nix
alwaysApply: false
---

## Description
This rule enforces best practices for testing and quality assurance in Nix derivations.

## Rule Details
- Enable tests by default with `doCheck = true`
- Use `checkPhase` for running unit and integration tests
- Use `installCheckPhase` for post-installation tests
- Use `passthru.tests` for running additional test suites
- Use `meta.tests` for documenting test coverage
- Use `meta.broken` to mark broken packages
- Use `meta.platforms` to specify supported platforms
- Use `meta.maintainers` to list package maintainers
- Use `meta.license` to specify package licenses
- Use `meta.homepage` to link to package documentation

## Key Rationale
The guidance emphasizes that "comprehensive testing ensures package reliability" and that "post-installation tests verify correct installation." Additional test suites help "catch integration issues," while proper metadata prevents installation failures and ensures appropriate package stewardship.

## Good Practice Example
A well-constructed derivation enables testing (`doCheck = true`), implements test phases, includes post-installation verification, defines additional test suites via `passthru.tests`, and populates comprehensive metadata with descriptions, licensing, platform specifications, and maintainer information.

## Anti-Pattern
Conversely, packages lacking test configuration, metadata information, and platform specifications represent inadequate quality assurance practices.
</system-reminder>
EOF

exit 0
