#!/usr/bin/env bash
set -euo pipefail

# Claude Code hook to prevent reflexive agreement responses
# Encourages substantive technical analysis instead of "you're right" responses
#
# Based on: https://gist.github.com/ljw1004/34b58090c16ee6d5e6f13fce07463a31
# Modified for NixOS integration and English-only communication

# Read stdin and extract transcript path
stdin=$(cat)
transcript_path=$(echo "$stdin" | jq -r ".transcript_path // empty")

# Exit gracefully if no transcript path is provided
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 0
fi

# Look through the last 5 assistant messages in the transcript
# Check for reflexive agreement phrases that should be avoided
items=$(grep '"role":"assistant"' "$transcript_path" 2>/dev/null | tail -n 5 || echo "")
needs_reminder=false

while IFS= read -r item; do
    # Skip empty lines
    [[ -n "$item" ]] || continue

    # Verify this is an assistant message with text content
    [[ "$(jq -r '.type // empty' <<< "$item")" == "assistant" ]] || continue
    [[ "$(jq -r '.message.content[0].type // empty' <<< "$item")" == "text" ]] || continue

    # Extract the text content and check first 80 characters for agreement phrases
    text=$(jq -r '.message.content[0].text // empty' <<< "$item")
    first_part="${text:0:80}"

    # Check for various forms of reflexive agreement
    if [[ "$first_part" =~ [Yy]ou.*(right|correct) ]] || \
       [[ "$first_part" =~ [Yy]ou.*absolutely ]] || \
       [[ "$first_part" =~ ^[Aa]bsolutely ]] || \
       [[ "$first_part" =~ ^[Ee]xactly ]] || \
       [[ "$first_part" =~ ^[Pp]recisely ]] || \
       [[ "$first_part" =~ ^[Tt]hat\'s.*correct ]] || \
       [[ "$first_part" =~ ^[Tt]hat\'s.*right ]] || \
       [[ "$first_part" =~ ^[Ii]ndeed ]] || \
       [[ "$first_part" =~ ^[Cc]orrect ]] || \
       [[ "$first_part" =~ [Yy]es.*exactly ]]; then
        needs_reminder=true
        break
    fi
done <<< "$items"

# Exit early if no reminder is needed
[[ "$needs_reminder" == "true" ]] || exit 0

# Output system reminder to encourage more analytical responses
cat <<'EOF'
<system-reminder>
You MUST NEVER use the phrase 'you are right' or similar reflexive agreement.

Avoid automatic agreement. Instead, provide substantive technical analysis.

You must always look for flaws, bugs, loopholes, counter-examples,
invalid assumptions in what the user writes. If you find none,
and find that the user is correct, you must state that dispassionately
and with a concrete specific reason for why you agree, before
continuing with your work.

<example>
user: It's failing on empty inputs, so we should add a null-check.
assistant: That approach addresses the immediate issue.
However, it's not idiomatic and doesn't consider the edge case
of an empty string. A more comprehensive approach would be to check
for falsy values using proper validation.
</example>

<example>
user: I'm concerned that we haven't handled connection failure.
assistant: I do see a potential connection failure edge case:
if the connection attempt on line 42 fails, the catch handler
on line 49 won't capture it properly. The most robust solution
would be to move failure handling up to the caller with proper
retry logic.
</example>
</system-reminder>
EOF

exit 0