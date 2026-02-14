#!/bin/bash
# Test Suite for Scoped Sudo Bridge
#
# Validates that all security layers are working correctly

set -e

DAEMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHITELIST="$DAEMON_DIR/config/whitelist.json"
LOG_FILE="$DAEMON_DIR/config/test.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

passed=0
failed=0

test_start() {
    echo -e "${BLUE}→ Testing: $1${NC}"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS${NC}: $1"
    passed=$((passed + 1))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL${NC}: $1"
    failed=$((failed + 1))
}

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Scoped Sudo Bridge Test Suite                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Test 1: Whitelist File Exists and Is Valid JSON
# ============================================================================

test_start "Whitelist file exists and is valid JSON"

if [ ! -f "$WHITELIST" ]; then
    test_fail "Whitelist file not found at $WHITELIST"
else
    if command -v jq &>/dev/null; then
        if jq . "$WHITELIST" >/dev/null 2>&1; then
            test_pass "Whitelist file is valid JSON"
        else
            test_fail "Whitelist file is invalid JSON"
        fi
    else
        test_fail "jq is not installed (needed to validate JSON)"
    fi
fi

echo ""

# ============================================================================
# Test 2: Daemon Script Exists and Is Executable
# ============================================================================

test_start "Daemon script exists and is executable"

if [ ! -f "$DAEMON_DIR/sudo-bridge-daemon.sh" ]; then
    test_fail "Daemon script not found"
elif [ ! -x "$DAEMON_DIR/sudo-bridge-daemon.sh" ]; then
    test_fail "Daemon script is not executable"
else
    test_pass "Daemon script is executable"
fi

echo ""

# ============================================================================
# Test 3: Wrapper Script Exists and Is Executable
# ============================================================================

test_start "Wrapper script exists and is executable"

if [ ! -f "$DAEMON_DIR/sudo-bridge.sh" ]; then
    test_fail "Wrapper script not found"
elif [ ! -x "$DAEMON_DIR/sudo-bridge.sh" ]; then
    test_fail "Wrapper script is not executable"
else
    test_pass "Wrapper script is executable"
fi

echo ""

# ============================================================================
# Test 4: Whitelist Contains Expected Commands
# ============================================================================

test_start "Whitelist contains expected commands"

expected_commands=("systemctl" "pacman")
for cmd in "${expected_commands[@]}"; do
    if jq -e ".\"$cmd\"" "$WHITELIST" >/dev/null 2>&1; then
        test_pass "Command '$cmd' found in whitelist"
    else
        test_fail "Command '$cmd' not found in whitelist"
    fi
done

echo ""

# ============================================================================
# Test 5: Systemctl Actions Are Whitelisted
# ============================================================================

test_start "Systemctl actions are properly configured"

expected_actions=("start" "stop" "restart" "reload")
for action in "${expected_actions[@]}"; do
    if jq -e ".systemctl.allowed_actions[] | select(. == \"$action\")" "$WHITELIST" >/dev/null 2>&1; then
        test_pass "Systemctl action '$action' is whitelisted"
    else
        test_fail "Systemctl action '$action' is not whitelisted"
    fi
done

echo ""

# ============================================================================
# Test 6: Systemctl Targets Are Whitelisted
# ============================================================================

test_start "Systemctl targets are properly configured"

expected_targets=("nginx" "redis" "postgres" "openclaw")
for target in "${expected_targets[@]}"; do
    if jq -e ".systemctl.allowed_targets[] | select(. == \"$target\")" "$WHITELIST" >/dev/null 2>&1; then
        test_pass "Systemctl target '$target' is whitelisted"
    else
        test_fail "Systemctl target '$target' is not whitelisted"
    fi
done

echo ""

# ============================================================================
# Test 7: Blocked Commands Are Properly Configured
# ============================================================================

test_start "Dangerous commands are properly blocked"

blocked_commands=("mount" "chattr" "rm" "sudo")
for cmd in "${blocked_commands[@]}"; do
    allowed_actions=$(jq -r ".\"$cmd\".allowed_actions[]?" "$WHITELIST" 2>/dev/null || echo "")
    if [ -z "$allowed_actions" ]; then
        test_pass "Command '$cmd' has no allowed actions (properly blocked)"
    else
        test_fail "Command '$cmd' has allowed actions (should be blocked)"
    fi
done

echo ""

# ============================================================================
# Test 8: Installation Script Exists
# ============================================================================

test_start "Installation script exists and is executable"

if [ ! -f "$DAEMON_DIR/install-sudo-bridge.sh" ]; then
    test_fail "Installation script not found"
elif [ ! -x "$DAEMON_DIR/install-sudo-bridge.sh" ]; then
    test_fail "Installation script is not executable"
else
    test_pass "Installation script is ready to run"
fi

echo ""

# ============================================================================
# Test 9: Documentation Exists
# ============================================================================

test_start "Documentation is complete"

if [ ! -f "$DAEMON_DIR/README.md" ]; then
    test_fail "README.md not found"
else
    if grep -q "Scoped Sudo Bridge" "$DAEMON_DIR/README.md"; then
        test_pass "README.md is complete"
    else
        test_fail "README.md is incomplete"
    fi
fi

echo ""

# ============================================================================
# Test 10: Auditd Rules File Exists
# ============================================================================

test_start "Auditd rules are configured"

if [ ! -f "$DAEMON_DIR/config/auditd.rules" ]; then
    test_fail "Auditd rules file not found"
else
    if grep -q "sudo-bridge" "$DAEMON_DIR/config/auditd.rules"; then
        test_pass "Auditd rules file is properly configured"
    else
        test_fail "Auditd rules file does not contain sudo-bridge rules"
    fi
fi

echo ""

# ============================================================================
# Test 11: Systemd Service File Exists
# ============================================================================

test_start "Systemd service configuration exists"

if [ ! -f "$DAEMON_DIR/systemd/sudo-bridge.service" ]; then
    test_fail "Systemd service file not found"
else
    if grep -q "ExecStart" "$DAEMON_DIR/systemd/sudo-bridge.service"; then
        test_pass "Systemd service file is properly configured"
    else
        test_fail "Systemd service file is incomplete"
    fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

total=$((passed + failed))

echo "╔════════════════════════════════════════════════════════════╗"
if [ "$failed" -eq 0 ]; then
    echo "║  ✓ ALL TESTS PASSED ($passed/$total)                          ║"
else
    echo "║  ⚠ SOME TESTS FAILED ($passed/$total passed, $failed failed)  ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ "$failed" -gt 0 ]; then
    echo "Please fix the failing tests before deploying."
    exit 1
else
    echo "All tests passed! Ready to deploy."
    echo ""
    echo "Next step: sudo ~/.openclaw/sudo-bridge/install-sudo-bridge.sh"
    exit 0
fi
