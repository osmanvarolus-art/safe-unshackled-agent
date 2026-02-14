#!/bin/bash
# Scoped Sudo Bridge — Wrapper for Agent Privilege Escalation
#
# Usage: sudo-bridge.sh COMMAND ACTION [TARGET] [REASON]
#
# Examples:
#   sudo-bridge.sh systemctl restart nginx
#   sudo-bridge.sh pacman -Syu
#   sudo-bridge.sh mount /dev/sda1 /mnt
#
# This wrapper validates against a whitelist, logs the operation to auditd,
# and executes the privileged command safely.

set -e

# Configuration
DAEMON_SOCKET="/run/sudo-bridge.sock"
DAEMON_PID_FILE="/run/sudo-bridge.pid"
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"
WHITELIST_FILE="$CONFIG_DIR/whitelist.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() {
    echo -e "${RED}✗ ERROR${NC}: $1" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Validate arguments
if [ $# -lt 2 ]; then
    log_error "Usage: sudo-bridge.sh COMMAND ACTION [TARGET] [REASON]"
    echo ""
    echo "Examples:"
    echo "  sudo-bridge.sh systemctl restart nginx"
    echo "  sudo-bridge.sh pacman -Syu"
    echo "  sudo-bridge.sh mount /dev/sda1 /mnt"
    exit 1
fi

COMMAND="$1"
ACTION="$2"
TARGET="${3:-}"
REASON="${4:-}"

# Validate whitelist file exists
if [ ! -f "$WHITELIST_FILE" ]; then
    log_error "Whitelist file not found: $WHITELIST_FILE"
    exit 1
fi

log_info "Validating operation: $COMMAND $ACTION $TARGET"

# Call daemon via socket or directly
# For now, we'll call the daemon script directly
# In production, this would use socket activation
/opt/uncaged/sudo-bridge-daemon.sh "$COMMAND" "$ACTION" "$TARGET" "$REASON"

exit $?
