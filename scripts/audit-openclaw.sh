#!/bin/bash
# OpenClaw Audit Query Helper
# Provides daily summary of auditd monitoring
# Usage: ./audit-openclaw.sh [KEY]
#   Default: summary of all monitored keys
#   KEY: specific key to query (agent-ssh, agent-creds, agent-pacman, etc.)

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_header() {
    echo -e "${BLUE}$1${NC}"
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if auditd is running
if ! systemctl is-active --quiet auditd; then
    log_error "auditd is not running"
    echo "Start with: sudo systemctl start auditd"
    exit 1
fi

# If specific key provided, query just that
if [ -n "$1" ]; then
    log_header "=== Audit Log for Key: $1 ==="
    echo ""
    sudo ausearch -k "$1" -i 2>/dev/null || log_error "No events found for key: $1"
    exit 0
fi

# Otherwise, provide summary
log_header "=== OpenClaw Audit Summary (Last 24 Hours) ==="
echo ""

log_header "System Authentication Access"
sudo ausearch -k agent-etc -i --start recent 2>/dev/null | head -5 || log_warning "No access to /etc/passwd, /etc/shadow, /etc/sudoers"
echo ""

log_header "SSH Key Access"
SSH_COUNT=$(sudo ausearch -k agent-ssh -i --start recent 2>/dev/null | grep -c "type=PATH" || echo "0")
if [ "$SSH_COUNT" = "0" ]; then
    log_info "No SSH key access detected"
else
    log_warning "SSH key access detected: $SSH_COUNT events"
    sudo ausearch -k agent-ssh -i --start recent 2>/dev/null | head -10
fi
echo ""

log_header "Credentials Access"
CREDS_COUNT=$(sudo ausearch -k agent-creds -i --start recent 2>/dev/null | grep -c "type=PATH" || echo "0")
if [ "$CREDS_COUNT" = "0" ]; then
    log_info "No credential file access detected"
else
    log_warning "Credential access detected: $CREDS_COUNT events"
    sudo ausearch -k agent-creds -i --start recent 2>/dev/null | head -10
fi
echo ""

log_header "Package Manager Execution"
PKG_COUNT=$(sudo ausearch -k agent-pacman -i --start recent 2>/dev/null | grep -c "type=EXECVE" || echo "0")
if [ "$PKG_COUNT" = "0" ]; then
    log_info "No package manager execution detected"
else
    log_warning "Package manager executed: $PKG_COUNT times"
    sudo ausearch -k agent-pacman -i --start recent 2>/dev/null | head -10
fi
echo ""

log_header "Boot Configuration Access"
BOOT_COUNT=$(sudo ausearch -k agent-boot -i --start recent 2>/dev/null | grep -c "type=PATH" || echo "0")
if [ "$BOOT_COUNT" = "0" ]; then
    log_info "No boot config modifications detected"
else
    log_warning "Boot config accessed: $BOOT_COUNT events"
    sudo ausearch -k agent-boot -i --start recent 2>/dev/null | head -10
fi
echo ""

log_header "Quick Reference"
echo ""
echo "To view detailed logs for specific key:"
echo "  sudo ausearch -k agent-ssh -i                 # SSH key access"
echo "  sudo ausearch -k agent-creds -i               # Credentials access"
echo "  sudo ausearch -k agent-pacman -i              # Package manager"
echo "  sudo ausearch -k agent-etc -i                 # /etc changes"
echo ""

echo "To view logs from specific date:"
echo "  sudo ausearch -k agent-ssh --start 2026-02-14 -i"
echo ""

echo "To export logs:"
echo "  sudo ausearch -k agent-ssh -i > audit-export.txt"
echo ""
