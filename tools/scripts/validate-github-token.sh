#!/usr/bin/env bash

# GitHub Token Validator for NixOS/sops
# Validates GitHub personal access token from sops secrets

set -euo pipefail

# Check if sops secret exists and is readable
GITHUB_TOKEN_PATH="/run/secrets/github/token"
if [[ ! -f "$GITHUB_TOKEN_PATH" ]]; then
    echo "❌ GitHub token secret not found at $GITHUB_TOKEN_PATH"
    echo "Make sure secrets are deployed with: sudo nixos-rebuild switch --flake ."
    exit 1
fi

# Read the token
TOKEN=$(cat "$GITHUB_TOKEN_PATH" 2>/dev/null || {
    echo "❌ Cannot read GitHub token from $GITHUB_TOKEN_PATH"
    echo "Check permissions or re-deploy secrets"
    exit 1
})

if [[ -z "$TOKEN" ]]; then
    echo "❌ GitHub token is empty"
    exit 1
fi

echo "🔍 Validating GitHub token..."

# Test token with GitHub API
RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
    -H "User-Agent: NixOS-Token-Validator" \
    "https://api.github.com/user" || {
    echo "❌ Failed to connect to GitHub API"
    exit 1
})

# Check if response contains error
if echo "$RESPONSE" | grep -q '"message".*"Bad credentials"'; then
    echo "❌ GitHub token is invalid or expired"
    echo "Response: $RESPONSE"
    echo ""
    echo "To fix:"
    echo "1. Generate new token at: https://github.com/settings/tokens"
    echo "2. Update secrets: EDITOR=nano sops edit secrets/secrets.yaml"
    echo "3. Redeploy: sudo nixos-rebuild switch --flake ."
    exit 1
fi

# Extract user info for validation
USERNAME=$(echo "$RESPONSE" | jq -r '.login // "unknown"')
SCOPES=$(curl -s -I -H "Authorization: token $TOKEN" \
    "https://api.github.com/user" | grep -i "x-oauth-scopes" | cut -d' ' -f2- | tr -d '\r\n' || echo "unknown")

echo "✅ GitHub token is valid!"
echo "📋 Token details:"
echo "   User: $USERNAME"
echo "   Scopes: $SCOPES"

# Check specific scopes needed for Nix
if echo "$SCOPES" | grep -q "repo\|public_repo"; then
    echo "✅ Has repository access scope"
else
    echo "⚠️  Missing repository access scope - may cause issues with private repos"
fi

echo ""
echo "🔧 Token is working for GitHub API access"