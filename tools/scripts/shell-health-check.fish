#!/usr/bin/env fish

# Shell Health Check Script
# Validates shell configurations and dependencies before deployment
#
# Exit codes:
#   0 - All checks passed or only warnings found
#   1 - Critical issues found
#   125 - Test skipped (reserved for future use)

set -g health_check_passed true
set -g issues_found 0

function log_info
    echo "ℹ️  $argv"
end

function log_warning
    echo "⚠️  $argv"
    set -g issues_found (math $issues_found + 1)
end

function log_error
    echo "❌ $argv"
    set -g health_check_passed false
    set -g issues_found (math $issues_found + 1)
end

function log_success
    echo "✅ $argv"
end

function check_command
    set -l cmd "$argv[1]"
    set -l description "$argv[2]"

    # Use proper test command with quoted variables
    if test -n "$(command -v "$cmd")"
        log_success "$description ($cmd) is available"
        return 0
    else
        log_warning "$description ($cmd) is not available"
        return 1
    end
end

function test_shell_startup
    set -l shell_cmd $argv[1]
    set -l shell_name $argv[2]

    # Skip during Home Manager activation - shells load full configs
    # which hang in the constrained activation environment
    if set -q HM_ACTIVATION
        log_info "Skipping $shell_name startup test (activation context)"
        return 0
    end

    log_info "Testing $shell_name startup safety..."

    # Test basic startup using proper Fish test syntax
    if eval "$shell_cmd" -c 'exit' >/dev/null 2>&1
        log_success "$shell_name basic startup test passed"
    else
        log_error "$shell_name basic startup test failed"
        return 1
    end

    # Test with timeout if available using proper test command
    if test -n "$(command -v timeout)"
        if timeout 5s eval "$shell_cmd" -c 'exit' >/dev/null 2>&1
            log_success "$shell_name timeout safety test passed"
        else
            log_error "$shell_name startup hangs or times out"
            return 1
        end
    end

    return 0
end

function validate_fish_config
    log_info "Validating Fish shell configuration..."

    # Skip full config validation during activation - config loads can hang
    # in the constrained activation environment
    if set -q HM_ACTIVATION
        log_info "Skipping fish config validation (activation context)"
        return 0
    end

    # Test Fish configuration syntax using proper test command
    if fish --no-config -c 'exit' >/dev/null 2>&1
        log_success "Fish shell basic functionality works"
    else
        log_error "Fish shell basic functionality failed"
        return 1
    end

    # Test Fish configuration loading
    if fish -c 'exit' >/dev/null 2>&1
        log_success "Fish configuration loads successfully"
    else
        log_warning "Fish configuration has issues"
        return 1
    end

    return 0
end

function validate_zellij_config
    log_info "Validating Zellij configuration..."

    # Use proper test command with string testing
    if test -z "$(command -v zellij)"
        log_warning "Zellij is not installed"
        return 1
    end

    # Test zellij help
    if zellij --help >/dev/null 2>&1
        log_success "Zellij binary is functional"
    else
        log_error "Zellij binary is not functional"
        return 1
    end

    # Test zellij configuration
    if zellij setup --check >/dev/null 2>&1
        log_success "Zellij configuration is valid"
    else
        log_warning "Zellij configuration validation failed"
        echo "  Run 'zellij setup --check' for details"
        return 1
    end

    return 0
end

function check_emergency_mechanisms
    log_info "Testing emergency shell mechanisms..."

    # Skip during Home Manager activation - system scripts not yet available
    if set -q HM_ACTIVATION
        log_info "Skipping emergency mechanism tests (activation context)"
        return 0
    end

    # Test emergency mode detection
    if emergency-mode-check >/dev/null 2>&1
        log_info "System is in emergency mode"
    else
        log_success "System is in normal mode"
    end

    # Test emergency functions are available
    if functions -q emergency-status
        log_success "Emergency shell functions are available"
        emergency-status
    else
        log_warning "Emergency shell functions not found"
    end

    # Test emergency functions existence
    if type -q emergency-help
        log_success "Emergency help function is available"
    else
        log_warning "Emergency help function is not available"
    end

    return 0
end

function check_critical_dependencies
    log_info "Checking critical dependencies..."

    # Essential commands that should always be available
    check_command "fish" "Fish shell"
    check_command "bash" "Bash shell"
    check_command "timeout" "Timeout command (for safety checks)"
    check_command "pgrep" "Process grep (for zellij detection)"

    # Nice-to-have commands
    check_command "zellij" "Zellij terminal multiplexer"
    check_command "direnv" "Directory environment manager"
    check_command "starship" "Starship prompt"
    check_command "zoxide" "Zoxide directory jumper"

    return 0
end

function main
    echo "🏥 Shell Configuration Health Check"
    echo "=================================="
    echo ""

    check_critical_dependencies
    echo ""

    test_shell_startup "bash" "Bash"
    echo ""

    test_shell_startup "fish" "Fish"
    echo ""

    validate_fish_config
    echo ""

    validate_zellij_config
    echo ""

    check_emergency_mechanisms
    echo ""

    # Summary using proper test syntax
    echo "📊 Health Check Summary"
    echo "======================"

    if test "$health_check_passed" = "true"
        if test "$issues_found" -eq 0
            log_success "All checks passed! Shell configuration is healthy."
            exit 0
        else
            echo "✅ Critical checks passed, but $issues_found warnings found."
            echo "   Review warnings above for potential improvements."
            exit 0
        end
    else
        log_error "Health check failed! Critical issues found."
        echo "   Fix the errors above before deploying configuration."
        exit 1
    end
end

# Function that can be called by Fish testing framework
function run_shell_health_tests
    # Reset global state for test runs
    set -g health_check_passed true
    set -g issues_found 0

    # Run the health check
    main
end

# When run as a script (not sourced), execute main
if not status --is-interactive
    main
end
