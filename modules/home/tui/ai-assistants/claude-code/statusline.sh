#!/bin/bash

# Claude Code NixOS Developer Statusline
# Optimized for performance and simplicity
# Focus on: Nix env, git status, directory, model

# Debug logging (enabled by default for debugging)
DEBUG_LOG="/tmp/claude-statusline-debug.log"
DEBUG_ENABLED="${CLAUDE_STATUSLINE_DEBUG:-true}"

# Read JSON input from stdin
input=$(cat)

# Log to debug file if enabled
if [[ "$DEBUG_ENABLED" == "true" ]]; then
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S.%N') ==="
        echo "Statusline called!"
        echo "Input JSON:"
        echo "$input" | jq '.' 2>/dev/null || echo "$input"
        echo ""
    } >> "$DEBUG_LOG"
fi

# Extract essential values from JSON with defaults
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null || echo "Claude")
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"' 2>/dev/null || echo "~")
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

# Simplified Nix Environment Detection
get_nix_env_info() {
    # Check for flake.nix (highest priority for NixOS config)
    [[ -f "flake.nix" ]] && echo "\033[1;94m✨flake\033[0m" && return

    # Check active nix environments
    [[ "$IN_NIX_SHELL" == "pure" ]] && echo "\033[1;94m❄️pure\033[0m" && return
    [[ -n "$IN_NIX_SHELL" ]] && echo "\033[1;94m❄️shell\033[0m" && return
    [[ -n "$DEVSHELL_ROOT" ]] && echo "\033[1;94m🛠️dev\033[0m" && return

    # Check for nix files
    [[ -f "shell.nix" || -f "default.nix" ]] && echo "\033[1;94m❄️nix\033[0m" && return
}

# Simplified Git Status - Single porcelain command
get_git_status() {
    # Quick git repo check
    git rev-parse --git-dir >/dev/null 2>&1 || return

    # Get branch and status in one go
    local branch=$(git branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && return

    # Single porcelain call for all file status
    local porcelain=$(git status --porcelain 2>/dev/null)

    # Count changes efficiently
    local staged=0 modified=0 untracked=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        case "${line:0:2}" in
            "??") ((untracked++)) ;;
            ?[MD]) ((modified++)) ;;
            [MADRC]?) ((staged++)) ;;
        esac
    done <<< "$porcelain"

    # Determine branch color
    local branch_color="\033[1;92m"  # green
    [[ $((staged + modified + untracked)) -gt 0 ]] && branch_color="\033[1;91m"  # red

    # Build status string
    local status="${branch_color}${branch}\033[0m"

    # Add compact change indicators
    [[ $staged -gt 0 ]] && status+=" \033[1;92m+$staged\033[0m"
    [[ $modified -gt 0 ]] && status+=" \033[1;93m!$modified\033[0m"
    [[ $untracked -gt 0 ]] && status+=" \033[1;94m?$untracked\033[0m"

    echo "$status"
}

# Simple Context Tracking (optional)
get_context_info() {
    [[ ! -f "$transcript_path" ]] && return

    # Simple turn count - no complex calculations or file I/O
    local turns=$(grep -c '"role": "user"' "$transcript_path" 2>/dev/null || echo "0")
    [[ $turns -eq 0 ]] && return

    # Simple color coding based on turn count
    local color="\033[1;92m"  # green
    [[ $turns -gt 15 ]] && color="\033[1;93m"  # yellow
    [[ $turns -gt 25 ]] && color="\033[1;91m"  # red

    echo "${color}${turns}t\033[0m"
}

# Context Window Usage (using current_usage field from Claude Code 2.0.70+)
get_context_usage() {
    # Extract context window data from input JSON
    local context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null || echo "0")
    local usage=$(echo "$input" | jq '.context_window.current_usage' 2>/dev/null)

    # Return if no context window data or current_usage is null
    [[ "$context_size" -eq 0 || "$usage" == "null" || -z "$usage" ]] && return

    # Calculate total tokens in context window
    # Sum: input_tokens + cache_creation_input_tokens + cache_read_input_tokens
    # Note: output_tokens not included (they don't consume context window)
    local input_tokens=$(echo "$usage" | jq -r '.input_tokens // 0')
    local cache_creation=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
    local cache_read=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')

    local current_tokens=$((input_tokens + cache_creation + cache_read))
    [[ $current_tokens -eq 0 ]] && return

    # Calculate percentage
    local percent_used=$((current_tokens * 100 / context_size))

    # Color code based on usage level
    local color="\033[1;92m"  # green (0-70%)
    [[ $percent_used -gt 70 ]] && color="\033[1;93m"  # yellow (70-90%)
    [[ $percent_used -gt 90 ]] && color="\033[1;91m"  # red (90-100%)

    # Format: "XX%" or "XX.X%" for values < 10%
    if [[ $percent_used -lt 10 ]]; then
        # Show decimal for low percentages
        local precise=$((current_tokens * 1000 / context_size))
        local whole=$((precise / 10))
        local decimal=$((precise % 10))
        echo "${color}${whole}.${decimal}%\033[0m"
    else
        echo "${color}${percent_used}%\033[0m"
    fi
}

# Build optimized statusline - single line, essential info
nix_env=$(get_nix_env_info)
git_info=$(get_git_status)
context_info=$(get_context_info)
context_usage=$(get_context_usage)
dir_name=$(basename "$current_dir" 2>/dev/null || echo "~")

# Build compact status line
status_line=""

# Nix environment (priority for NixOS)
[[ -n "$nix_env" ]] && status_line+="$nix_env "

# Directory
status_line+="\033[1;94m$dir_name\033[0m"

# Git info
[[ -n "$git_info" ]] && status_line+=" $git_info"

# Context window percentage
[[ -n "$context_usage" ]] && status_line+=" $context_usage"

# Context info (turns)
[[ -n "$context_info" ]] && status_line+=" $context_info"

# Model
status_line+=" \033[1;96m$model_name\033[0m"

# Log output if debug enabled
if [[ "$DEBUG_ENABLED" == "true" ]]; then
    {
        echo "Output:"
        echo "$status_line"
        echo "---"
        echo ""
    } >> "$DEBUG_LOG"
fi

# Output single line with proper color handling
printf "%b\n" "$status_line"
