#!/usr/bin/env bash
set -euo pipefail

# my-nix-tool - A template for Nix-based shell tools
# CHANGE THIS: Update description and tool name

# Configuration
TOOL_NAME="my-nix-tool"
TOOL_VERSION="0.1.0"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$TOOL_NAME"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$TOOL_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}WARN:${NC} $*" >&2
}

log_error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $*" >&2
}

# Help function
show_help() {
    cat << EOF
$TOOL_NAME v$TOOL_VERSION

USAGE:
    $TOOL_NAME [OPTIONS] <COMMAND> [ARGS...]

COMMANDS:
    init <target>       Initialize configuration in target directory
    run <input>         Run the main operation with input
    status              Show system status
    config              Show configuration
    help                Show this help message

OPTIONS:
    -v, --verbose       Enable verbose output
    -q, --quiet         Suppress non-error output
    -c, --config PATH   Use custom configuration file
    -d, --dry-run       Show what would be done without executing
    -h, --help          Show this help message

EXAMPLES:
    $TOOL_NAME init /tmp/myproject
    $TOOL_NAME run --output /tmp/result.json input.txt
    $TOOL_NAME status

CONFIGURATION:
    Config directory: $CONFIG_DIR
    Cache directory:  $CACHE_DIR
EOF
}

# Configuration management
load_config() {
    local config_file="${CONFIG_FILE:-$CONFIG_DIR/config.json}"

    if [[ -f "$config_file" ]]; then
        log_info "Loading configuration from $config_file"
        # TODO: Parse configuration file
        # CONFIG=$(jq -r '.' "$config_file")
    else
        log_info "No configuration file found, using defaults"
    fi
}

init_config_dir() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
}

# Command implementations
cmd_init() {
    local target="${1:-$(pwd)}"

    log_info "Initializing $TOOL_NAME in $target"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create configuration in $target"
        return 0
    fi

    # Create target directory
    mkdir -p "$target"

    # TODO: Add your initialization logic here
    # Example: Create configuration files, directories, etc.

    log_success "Initialized successfully in $target"
}

cmd_run() {
    local input="$1"
    local output="${OUTPUT:-}"

    log_info "Running $TOOL_NAME with input: $input"

    if [[ ! -f "$input" ]]; then
        log_error "Input file not found: $input"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would process $input"
        [[ -n "$output" ]] && log_info "DRY RUN: Would write output to $output"
        return 0
    fi

    # TODO: Add your main processing logic here
    local result
    result=$(echo "Processed: $(basename "$input")")

    if [[ -n "$output" ]]; then
        echo "$result" > "$output"
        log_success "Output written to $output"
    else
        echo "$result"
    fi

    log_success "Processing completed"
}

cmd_status() {
    log_info "System Status for $TOOL_NAME"
    echo "Tool Version: $TOOL_VERSION"
    echo "Config Directory: $CONFIG_DIR"
    echo "Cache Directory: $CACHE_DIR"

    # Add system-specific status checks
    echo "Hostname: $(hostname)"
    echo "Current User: $(whoami)"
    echo "Working Directory: $(pwd)"

    # TODO: Add tool-specific status checks
    # Check if required tools are available
    local required_tools=("jq" "curl")  # Add tools your script needs
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✓ $tool: available"
        else
            echo "✗ $tool: missing"
        fi
    done
}

cmd_config() {
    log_info "Configuration for $TOOL_NAME"
    echo "Config file: ${CONFIG_FILE:-$CONFIG_DIR/config.json}"
    echo "Cache directory: $CACHE_DIR"

    # TODO: Show current configuration values
}

# Main argument parsing
main() {
    # Default values
    VERBOSE=false
    QUIET=false
    DRY_RUN=false
    CONFIG_FILE=""
    OUTPUT=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            init)
                shift
                init_config_dir
                load_config
                cmd_init "$@"
                exit $?
                ;;
            run)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "run command requires an input argument"
                    exit 1
                fi
                init_config_dir
                load_config
                cmd_run "$@"
                exit $?
                ;;
            status)
                init_config_dir
                load_config
                cmd_status
                exit 0
                ;;
            config)
                init_config_dir
                cmd_config
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use '$TOOL_NAME --help' for usage information."
                exit 1
                ;;
            *)
                log_error "Unknown command: $1"
                echo "Use '$TOOL_NAME --help' for usage information."
                exit 1
                ;;
        esac
    done

    # No command provided
    log_warn "No command specified"
    show_help
    exit 1
}

# Execute main function with all arguments
main "$@"
