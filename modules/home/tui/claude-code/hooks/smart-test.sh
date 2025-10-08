#!/usr/bin/env bash

# Smart testing script for Claude Code hooks
# Based on Veraticus implementation but adapted for NixOS

set -euo pipefail

# Configuration
HOOK_CONFIG_FILE=".claude-hooks-config.sh"
EXCLUDE_DIRS=("node_modules" ".git" "target" "dist" "build" ".next" ".vite" ".nuxt")
ENABLE_TEST_HOOK=true

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
if [[ "$ENABLE_TEST_HOOK" != "true" ]]; then
    echo '{"status": "success", "message": "Testing hook disabled"}'
    exit 0
fi

# Detect project type and testing framework
detect_project_type() {
    if [[ -f "flake.nix" ]] || [[ -f "default.nix" ]]; then
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

# Detect available testing frameworks
detect_test_framework() {
    local project_type="$1"

    case "$project_type" in
        "nix")
            if [[ -f "flake.nix" ]] && grep -q "checks" flake.nix; then
                echo "nix-checks"
            else
                echo "none"
            fi
            ;;
        "javascript")
            if [[ -f "package.json" ]]; then
                if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
                    echo "npm-test"
                elif jq -e '.devDependencies.vitest' package.json >/dev/null 2>&1; then
                    echo "vitest"
                elif jq -e '.devDependencies.jest' package.json >/dev/null 2>&1; then
                    echo "jest"
                else
                    echo "none"
                fi
            else
                echo "none"
            fi
            ;;
        "rust")
            if [[ -f "Cargo.toml" ]]; then
                echo "cargo-test"
            else
                echo "none"
            fi
            ;;
        "go")
            if [[ -f "go.mod" ]]; then
                echo "go-test"
            else
                echo "none"
            fi
            ;;
        "python")
            if [[ -f "pyproject.toml" ]] && grep -q "pytest" pyproject.toml; then
                echo "pytest"
            elif [[ -f "requirements.txt" ]] && grep -q "pytest" requirements.txt; then
                echo "pytest"
            elif find . -name "test_*.py" -o -name "*_test.py" | head -1 | grep -q .; then
                echo "pytest"
            else
                echo "none"
            fi
            ;;
        *)
            echo "none"
            ;;
    esac
}

# Find test files
find_test_files() {
    local project_type="$1"

    case "$project_type" in
        "javascript")
            find . -name "*.test.js" -o -name "*.test.ts" -o -name "*.spec.js" -o -name "*.spec.ts" -type f 2>/dev/null | head -20
            ;;
        "rust")
            # Rust tests are typically in the same files or in tests/ directory
            find . -path "./tests/*.rs" -type f 2>/dev/null | head -20
            ;;
        "go")
            find . -name "*_test.go" -type f 2>/dev/null | head -20
            ;;
        "python")
            find . -name "test_*.py" -o -name "*_test.py" -type f 2>/dev/null | head -20
            ;;
        *)
            echo ""
            ;;
    esac
}

# Run tests based on detected framework
run_tests() {
    local project_type="$1"
    local test_framework="$2"
    local test_files="$3"
    local has_errors=0

    case "$test_framework" in
        "nix-checks")
            log_info "Running nix flake check..."
            if ! nix flake check --no-build 2>/dev/null; then
                log_error "nix flake check failed"
                has_errors=1
            fi
            ;;

        "npm-test")
            log_info "Running npm test..."
            if ! npm test; then
                has_errors=1
            fi
            ;;

        "vitest")
            log_info "Running vitest..."
            if ! npx vitest run; then
                has_errors=1
            fi
            ;;

        "jest")
            log_info "Running jest..."
            if ! npx jest; then
                has_errors=1
            fi
            ;;

        "cargo-test")
            log_info "Running cargo test..."
            if ! cargo test; then
                has_errors=1
            fi
            ;;

        "go-test")
            log_info "Running go test..."
            if ! go test ./...; then
                has_errors=1
            fi
            ;;

        "pytest")
            log_info "Running pytest..."
            if command -v pytest >/dev/null 2>&1; then
                if ! pytest; then
                    has_errors=1
                fi
            elif command -v python3 >/dev/null 2>&1; then
                if ! python3 -m pytest; then
                    has_errors=1
                fi
            else
                log_warn "pytest not available"
            fi
            ;;

        "none")
            log_warn "No testing framework detected"
            ;;
    esac

    return $has_errors
}

# Run build checks if applicable
run_build_check() {
    local project_type="$1"
    local has_errors=0

    case "$project_type" in
        "nix")
            if [[ -f "flake.nix" ]]; then
                log_info "Running nix build check..."
                if ! nix build --dry-run 2>/dev/null; then
                    log_error "nix build check failed"
                    has_errors=1
                fi
            fi
            ;;

        "javascript")
            if [[ -f "package.json" ]] && jq -e '.scripts.build' package.json >/dev/null 2>&1; then
                log_info "Running npm run build..."
                if ! npm run build; then
                    has_errors=1
                fi
            fi
            ;;

        "rust")
            log_info "Running cargo build..."
            if ! cargo build; then
                has_errors=1
            fi
            ;;

        "go")
            log_info "Running go build..."
            if ! go build ./...; then
                has_errors=1
            fi
            ;;
    esac

    return $has_errors
}

main() {
    log_info "Starting smart test process..."

    local project_type
    project_type=$(detect_project_type)
    log_info "Detected project type: $project_type"

    local test_framework
    test_framework=$(detect_test_framework "$project_type")
    log_info "Detected test framework: $test_framework"

    local test_files
    test_files=$(find_test_files "$project_type")

    if [[ -n "$test_files" ]]; then
        log_info "Found $(echo "$test_files" | wc -l) test files"
    else
        log_warn "No test files found"
    fi

    local has_test_errors=0
    local has_build_errors=0

    # Run tests
    if ! run_tests "$project_type" "$test_framework" "$test_files"; then
        has_test_errors=1
    fi

    # Run build check
    if ! run_build_check "$project_type"; then
        has_build_errors=1
    fi

    # Determine overall result
    if [[ $has_test_errors -eq 0 && $has_build_errors -eq 0 ]]; then
        log_success "All tests and build checks passed!"
        echo '{"status": "success", "message": "Testing completed successfully"}'
        exit 0
    else
        local error_msg="Issues found:"
        if [[ $has_test_errors -eq 1 ]]; then
            error_msg="$error_msg test failures;"
        fi
        if [[ $has_build_errors -eq 1 ]]; then
            error_msg="$error_msg build errors;"
        fi

        log_error "$error_msg"
        echo "{\"status\": \"error\", \"message\": \"$error_msg Please fix before continuing.\"}"
        exit 1
    fi
}

main "$@"