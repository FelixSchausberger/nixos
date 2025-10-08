#!/usr/bin/env bash

# Smart linting script for Claude Code hooks
# Based on Veraticus implementation but adapted for NixOS

set -euo pipefail

# Configuration
HOOK_CONFIG_FILE=".claude-hooks-config.sh"
EXCLUDE_DIRS=("node_modules" ".git" "target" "dist" "build" ".next" ".vite" ".nuxt")
EXCLUDE_PATTERNS=("*.lock" "*.log" "*.tmp" "*.temp")
ENABLE_LINT_HOOK=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Load configuration if exists
if [[ -f "$HOOK_CONFIG_FILE" ]]; then
    source "$HOOK_CONFIG_FILE"
fi

# Skip if disabled in config
if [[ "$ENABLE_LINT_HOOK" != "true" ]]; then
    echo '{"status": "success", "message": "Linting hook disabled"}'
    exit 0
fi

# Detect project type and files to lint
detect_project_type() {
    if [[ -f "flake.nix" ]] || [[ -f "default.nix" ]] || find . -name "*.nix" -type f | head -1 | grep -q .; then
        echo "nix"
    elif [[ -f "package.json" ]]; then
        echo "javascript"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "go.mod" ]] || [[ -f "go.sum" ]]; then
        echo "go"
    elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
        echo "python"
    else
        echo "generic"
    fi
}

# Build exclusion arguments for find
build_find_exclusions() {
    local exclusions=()

    # Add directory exclusions
    for dir in "${EXCLUDE_DIRS[@]}"; do
        exclusions+=("-path" "./$dir" "-prune" "-o")
    done

    # Add pattern exclusions
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclusions+=("!" "-name" "$pattern")
    done

    echo "${exclusions[@]}"
}

# Find files to lint based on project type
find_files_to_lint() {
    local project_type="$1"
    local exclusions
    exclusions=($(build_find_exclusions))

    case "$project_type" in
        "nix")
            find . "${exclusions[@]}" -name "*.nix" -type f -print
            ;;
        "javascript")
            find . "${exclusions[@]}" -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -type f -print
            ;;
        "rust")
            find . "${exclusions[@]}" -name "*.rs" -type f -print
            ;;
        "go")
            find . "${exclusions[@]}" -name "*.go" -type f -print
            ;;
        "python")
            find . "${exclusions[@]}" -name "*.py" -type f -print
            ;;
        "generic")
            find . "${exclusions[@]}" -name "*.sh" -o -name "*.bash" -type f -print
            ;;
    esac
}

# Run project-specific linters
run_project_linters() {
    local project_type="$1"
    local files_to_lint="$2"
    local has_errors=0

    case "$project_type" in
        "nix")
            # Check for project-specific Nix commands first
            if command -v alejandra >/dev/null 2>&1; then
                log_info "Running alejandra formatter check on Nix files..."
                if ! echo "$files_to_lint" | xargs alejandra --check 2>/dev/null; then
                    log_error "alejandra formatting issues found"
                    has_errors=1
                fi
            fi

            if command -v deadnix >/dev/null 2>&1; then
                log_info "Running deadnix on Nix files..."
                if ! echo "$files_to_lint" | xargs deadnix 2>/dev/null; then
                    log_error "deadnix found dead code"
                    has_errors=1
                fi
            fi
            ;;

        "javascript")
            # Check for project-specific commands
            if [[ -f "package.json" ]] && jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
                log_info "Running npm run lint..."
                if ! npm run lint; then
                    has_errors=1
                fi
            elif command -v eslint >/dev/null 2>&1; then
                log_info "Running eslint..."
                if ! echo "$files_to_lint" | xargs eslint; then
                    has_errors=1
                fi
            fi
            ;;

        "rust")
            if [[ -f "Cargo.toml" ]]; then
                log_info "Running cargo clippy..."
                if ! cargo clippy -- -D warnings; then
                    has_errors=1
                fi

                log_info "Running cargo fmt check..."
                if ! cargo fmt -- --check; then
                    has_errors=1
                fi
            fi
            ;;

        "go")
            if command -v golangci-lint >/dev/null 2>&1; then
                log_info "Running golangci-lint..."
                if ! golangci-lint run; then
                    has_errors=1
                fi
            elif command -v go >/dev/null 2>&1; then
                log_info "Running go vet..."
                if ! go vet ./...; then
                    has_errors=1
                fi
            fi
            ;;

        "python")
            if [[ -f "pyproject.toml" ]] && command -v ruff >/dev/null 2>&1; then
                log_info "Running ruff check..."
                if ! ruff check .; then
                    has_errors=1
                fi
            elif command -v flake8 >/dev/null 2>&1; then
                log_info "Running flake8..."
                if ! echo "$files_to_lint" | xargs flake8; then
                    has_errors=1
                fi
            fi
            ;;

        "generic")
            if command -v shellcheck >/dev/null 2>&1 && [[ -n "$files_to_lint" ]]; then
                log_info "Running shellcheck on shell scripts..."
                if ! echo "$files_to_lint" | xargs shellcheck; then
                    has_errors=1
                fi
            fi
            ;;
    esac

    return $has_errors
}

main() {
    log_info "Starting smart lint process..."

    local project_type
    project_type=$(detect_project_type)
    log_info "Detected project type: $project_type"

    local files_to_lint
    files_to_lint=$(find_files_to_lint "$project_type")

    if [[ -z "$files_to_lint" ]]; then
        log_warn "No files found to lint for project type: $project_type"
        echo '{"status": "success", "message": "No files to lint"}'
        exit 0
    fi

    log_info "Found $(echo "$files_to_lint" | wc -l) files to lint"

    if run_project_linters "$project_type" "$files_to_lint"; then
        log_success "All linting checks passed!"
        echo '{"status": "success", "message": "Linting completed successfully"}'
        exit 0
    else
        log_error "Linting issues found"
        echo '{"status": "error", "message": "Linting issues detected. Please fix before continuing."}'
        exit 1
    fi
}

main "$@"