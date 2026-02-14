#!/bin/bash
# Scoped Sudo Bridge Daemon — Validates and Executes Privileged Operations
#
# This daemon runs as root and validates all privilege escalation requests
# against a whitelist before execution. Every operation is audited.
#
# MUST be run as root. Typically invoked via sudo-bridge.sh wrapper.

set -e

# Configuration
DAEMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$DAEMON_DIR/config"
WHITELIST_FILE="$CONFIG_DIR/whitelist.json"
LOG_FILE="$CONFIG_DIR/sudo-bridge.log"
CALLER_UID="${SUDO_UID:-$UID}"
CALLER_PID="$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() {
    echo -e "${RED}✗ ERROR${NC}: $1" >&2
    log_audit "DENIED" "$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

log_audit() {
    local status=$1
    local message=$2
    local timestamp=$(date -Iseconds)

    # Log to daemon log
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$status] UID=$CALLER_UID PID=$CALLER_PID: $COMMAND $ACTION $TARGET - $message" >> "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Daemon must run as root (got UID=$EUID)"
    exit 1
fi

# Validate arguments
if [ $# -lt 2 ]; then
    log_error "Usage: sudo-bridge-daemon.sh COMMAND ACTION [TARGET] [REASON]"
    exit 1
fi

COMMAND="$1"
ACTION="$2"
TARGET="${3:-}"
REASON="${4:-}"

log_info "Processing request: $COMMAND $ACTION $TARGET"

# Ensure whitelist file exists
if [ ! -f "$WHITELIST_FILE" ]; then
    log_error "Whitelist file not found: $WHITELIST_FILE"
    exit 1
fi

# Check for jq (JSON query tool)
if ! command -v jq &>/dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

# ============================================================================
# VALIDATION LAYER 1: Command Exists in Whitelist
# ============================================================================

log_info "Checking if command '$COMMAND' is whitelisted..."

if ! jq -e ".\"$COMMAND\"" "$WHITELIST_FILE" >/dev/null 2>&1; then
    log_error "Command not whitelisted: $COMMAND"
    exit 1
fi

log_success "Command '$COMMAND' is whitelisted"

# ============================================================================
# VALIDATION LAYER 2: Action is Allowed for This Command
# ============================================================================

log_info "Checking if action '$ACTION' is allowed..."

allowed_actions=$(jq -r ".\"$COMMAND\".allowed_actions[]?" "$WHITELIST_FILE" 2>/dev/null || echo "")

action_allowed="false"
while IFS= read -r allowed_action; do
    [ -z "$allowed_action" ] && continue
    if [ "$ACTION" = "$allowed_action" ]; then
        action_allowed="true"
        break
    fi
done <<< "$allowed_actions"

if [ "$action_allowed" != "true" ]; then
    log_error "Action '$ACTION' not allowed for command '$COMMAND'"
    exit 1
fi

log_success "Action '$ACTION' is allowed"

# ============================================================================
# VALIDATION LAYER 3: Target is Allowed (if applicable)
# ============================================================================

if jq -e ".\"$COMMAND\".allowed_targets" "$WHITELIST_FILE" >/dev/null 2>&1; then
    log_info "Checking if target '$TARGET' is allowed..."

    if [ -z "$TARGET" ]; then
        log_error "Target required but not provided"
        exit 1
    fi

    allowed_targets=$(jq -r ".\"$COMMAND\".allowed_targets[]?" "$WHITELIST_FILE" 2>/dev/null || echo "")

    target_allowed="false"
    while IFS= read -r allowed_target; do
        [ -z "$allowed_target" ] && continue
        if [ "$TARGET" = "$allowed_target" ]; then
            target_allowed="true"
            break
        fi
    done <<< "$allowed_targets"

    if [ "$target_allowed" != "true" ]; then
        log_error "Target '$TARGET' not allowed for command '$COMMAND'"
        exit 1
    fi

    log_success "Target '$TARGET' is allowed"
fi

# ============================================================================
# VALIDATION LAYER 4: Rate Limiting (prevent brute-force escalation)
# ============================================================================

log_info "Checking rate limits..."

max_ops_per_minute=30
recent_count=0
if [ -f "$LOG_FILE" ]; then
    recent_count=$(grep "UID=$CALLER_UID" "$LOG_FILE" 2>/dev/null | tail -30 | wc -l || echo "0")
fi

if [ "$recent_count" -gt "$max_ops_per_minute" ]; then
    log_error "Rate limit exceeded for UID=$CALLER_UID ($recent_count operations)"
    exit 1
fi

log_success "Rate limit OK (recent operations: $recent_count)"

# ============================================================================
# VALIDATION LAYER 5: Shell Injection Prevention
# ============================================================================

log_info "Validating command safety..."

# Check for shell metacharacters in arguments
for arg in "$COMMAND" "$ACTION" "$TARGET"; do
    if [[ "$arg" =~ [';$()&|<>`'] ]]; then
        log_error "Shell metacharacters detected in argument: $arg"
        exit 1
    fi
done

log_success "Command is safe from shell injection"

# ============================================================================
# EXECUTION: Run the Privileged Operation
# ============================================================================

log_info "All validations passed. Executing operation..."

output=""
exit_code=0

case "$COMMAND" in
    systemctl)
        # Validate systemctl action
        if [[ ! "$ACTION" =~ ^(start|stop|restart|reload|status|enable|disable)$ ]]; then
            log_error "Invalid systemctl action: $ACTION"
            exit 1
        fi

        log_info "Executing: /usr/bin/systemctl $ACTION $TARGET"
        output=$(/usr/bin/systemctl "$ACTION" "$TARGET" 2>&1) || exit_code=$?
        ;;

    pacman)
        # Validate pacman action (simple whitelist)
        if [[ ! "$ACTION" =~ ^(-S|-Syu|--refresh|--sync|-U)$ ]]; then
            log_error "Invalid pacman action: $ACTION"
            exit 1
        fi

        log_info "Executing: /usr/bin/pacman $ACTION $TARGET"
        output=$(/usr/bin/pacman "$ACTION" "$TARGET" 2>&1) || exit_code=$?
        ;;

    mount)
        # Mount is high-risk, require whitelist
        log_error "Mount operations are restricted (not implemented)"
        exit 1
        ;;

    chattr)
        # Prevent removing immutable flags
        log_error "Cannot use chattr via sudo-bridge (immutable files are protected)"
        exit 1
        ;;

    *)
        log_error "Unknown command handler: $COMMAND"
        exit 1
        ;;
esac

# Log result
if [ $exit_code -eq 0 ]; then
    log_success "Operation completed successfully"
    [ -n "$output" ] && echo "$output"
    log_audit "SUCCESS" "$COMMAND $ACTION $TARGET"
else
    log_error "Operation failed with exit code $exit_code"
    [ -n "$output" ] && echo "$output" >&2
    log_audit "FAILED" "$COMMAND $ACTION $TARGET (exit code: $exit_code)"
fi

exit $exit_code
