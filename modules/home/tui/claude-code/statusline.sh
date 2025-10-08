#!/bin/bash

# Claude Code NixOS Developer Statusline
# Optimized for performance and simplicity
# Focus on: Nix env, git status, directory, model

# Read JSON input from stdin
input=$(cat)

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

# Usage Tracking via ccusage (optional)
get_usage_info() {
    # Check if ccusage is available
    command -v ccusage >/dev/null 2>&1 || return

    # Run ccusage statusline command (offline mode by default, fast)
    # This provides formatted usage info: session cost, today's cost, block info, burn rate
    local usage_output=$(ccusage statusline 2>/dev/null || echo "")

    # Return the formatted output from ccusage (already has color codes)
    if [[ -n "$usage_output" ]]; then
        echo "$usage_output"
    fi
}

# Build optimized statusline - single line, essential info
nix_env=$(get_nix_env_info)
git_info=$(get_git_status)
context_info=$(get_context_info)
usage_info=$(get_usage_info)
dir_name=$(basename "$current_dir" 2>/dev/null || echo "~")

# Build compact status line
status_line=""

# Nix environment (priority for NixOS)
[[ -n "$nix_env" ]] && status_line+="$nix_env "

# Directory
status_line+="\033[1;94m$dir_name\033[0m"

# Git info
[[ -n "$git_info" ]] && status_line+=" $git_info"

# Context info (turns)
[[ -n "$context_info" ]] && status_line+=" $context_info"

# Usage tracking (tokens/cost) - only if available
[[ -n "$usage_info" ]] && status_line+=" $usage_info"

# Model
status_line+=" \033[1;96m$model_name\033[0m"

# Output single line with proper color handling
printf "%b\n" "$status_line"