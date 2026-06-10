#!/usr/bin/env bash

# Claude Code hooks configuration file
# Copy this to your project root as .claude-hooks-config.sh and customize as needed

# Global hook settings
ENABLE_LINT_HOOK=true
ENABLE_TEST_HOOK=true

# Linting configuration
# Additional directories to exclude (beyond defaults)
ADDITIONAL_EXCLUDE_DIRS=()
# Additional file patterns to exclude
ADDITIONAL_EXCLUDE_PATTERNS=()

# Testing configuration
# Skip certain test types (e.g., "integration", "e2e")
SKIP_TEST_TYPES=()

# Project-specific overrides
# Set to specific commands if you want to override detection
CUSTOM_LINT_COMMAND=""
CUSTOM_TEST_COMMAND=""

# Notification settings (future enhancement)
NOTIFY_ON_SUCCESS=false
NOTIFY_ON_ERROR=true

# Example configurations:

# For a JavaScript project with custom linting:
# CUSTOM_LINT_COMMAND="npm run lint:custom"

# For a project with long-running tests:
# SKIP_TEST_TYPES=("integration" "e2e")

# To disable hooks entirely:
# ENABLE_LINT_HOOK=false
# ENABLE_TEST_HOOK=false

# Additional exclusions for monorepos:
# ADDITIONAL_EXCLUDE_DIRS=("apps/legacy" "packages/deprecated")
# ADDITIONAL_EXCLUDE_PATTERNS=("*.generated.ts" "*.pb.go")
