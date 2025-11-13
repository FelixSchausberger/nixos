#!/usr/bin/env bash
set -euo pipefail

# Claude Code Hook Orchestrator
# Coordinates multiple hooks and merges their outputs into single JSON response
# This allows multiple hooks to contribute context while respecting Claude Code's
# single JSON output requirement

# Hooks directory is set at build time via Nix substitution
# shellcheck disable=SC2154
HOOKS_DIR="@hooksDir@"
HOOKS_EXECUTED=()
ADDITIONAL_CONTEXTS=()
FINAL_EXIT_CODE=0

# Read stdin once and save it for all hooks
STDIN_CONTENT=$(cat)

# Function to run a hook and capture its output
run_hook() {
    local hook_name="$1"
    local hook_script="$HOOKS_DIR/$hook_name"
    local output
    local exit_code=0

    if [[ ! -x "$hook_script" ]]; then
        return 0
    fi

    # Run hook with stdin content, capture stdout
    output=$(echo "$STDIN_CONTENT" | "$hook_script" 2>/dev/null) || exit_code=$?

    # Track execution
    HOOKS_EXECUTED+=("$hook_name")

    # Handle exit codes
    if [[ $exit_code -eq 2 ]]; then
        # Blocking error - propagate immediately
        FINAL_EXIT_CODE=2
        return 2
    elif [[ $exit_code -ne 0 ]]; then
        # Non-blocking error
        if [[ $FINAL_EXIT_CODE -eq 0 ]]; then
            FINAL_EXIT_CODE=$exit_code
        fi
    fi

    # Extract additionalContext from hook output if it's JSON
    if [[ -n "$output" ]] && echo "$output" | jq -e . >/dev/null 2>&1; then
        local context
        context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty' 2>/dev/null)
        if [[ -n "$context" ]]; then
            ADDITIONAL_CONTEXTS+=("$context")
        fi
    elif [[ -n "$output" ]]; then
        # Non-JSON output (like system reminders) - include as context
        ADDITIONAL_CONTEXTS+=("$output")
    fi

    return 0
}

# Run all hooks in sequence
run_hook "prevent-rebuild.sh" || true
run_hook "avoid-agreement.sh" || true
run_hook "additional-context.sh" || true

# Build notification of executed hooks
hooks_list=$(IFS=', '; echo "${HOOKS_EXECUTED[*]}")
notification="✓ Hooks executed: ${hooks_list}"

# Combine all contexts
combined_context="$notification"
for ctx in "${ADDITIONAL_CONTEXTS[@]}"; do
    combined_context="${combined_context}

${ctx}"
done

# Output final JSON with merged context
jq -n \
    --arg ctx "$combined_context" \
    '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: $ctx
        }
    }'

exit $FINAL_EXIT_CODE
