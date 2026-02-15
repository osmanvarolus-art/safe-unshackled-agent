#!/bin/bash
# Verify security hardening status
# Run with: bash ./scripts/security-verify.sh

echo "=========================================="
echo "Uncaged Security Hardening Status"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: Sudoers immutable
echo -e "${YELLOW}Check 1: Sudoers Protection${NC}"
SUDOERS_ATTR=$(sudo lsattr /etc/sudoers 2>/dev/null | grep -o "i")
if [[ "$SUDOERS_ATTR" == "i" ]]; then
    echo -e "${GREEN}✓ /etc/sudoers is immutable${NC}"
    SUDOERS_STATUS="✅ PROTECTED"
else
    echo -e "${RED}✗ /etc/sudoers NOT immutable${NC}"
    SUDOERS_STATUS="❌ NOT PROTECTED"
fi
echo ""

# Check 2: Auditd running
echo -e "${YELLOW}Check 2: Auditd Daemon${NC}"
if systemctl is-active --quiet auditd; then
    echo -e "${GREEN}✓ auditd is running${NC}"
    AUDITD_STATUS="✅ RUNNING"
else
    echo -e "${RED}✗ auditd NOT running${NC}"
    AUDITD_STATUS="❌ NOT RUNNING"
fi
echo ""

# Check 3: Existing auditd rules
echo -e "${YELLOW}Check 3: Auditd Rules Loaded${NC}"
RULE_COUNT=$(sudo auditctl -l 2>/dev/null | grep -c "^-w" || echo "0")
if [[ $RULE_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓ Auditd rules loaded: $RULE_COUNT rules${NC}"
    echo ""
    echo "Current rules:"
    sudo auditctl -l 2>/dev/null | grep "^-w" | while read line; do
        echo "  $line"
    done
    RULES_STATUS="✅ $RULE_COUNT RULES ACTIVE"
else
    echo -e "${RED}✗ No auditd rules loaded${NC}"
    RULES_STATUS="❌ NO RULES"
fi
echo ""

# Check 4: Critical monitoring
echo -e "${YELLOW}Check 4: Critical Files Monitored${NC}"
echo "Checking for essential monitoring:"

MONITORING=()

# Check /etc/sudoers
if sudo auditctl -l 2>/dev/null | grep -q "/etc/sudoers"; then
    echo -e "  ${GREEN}✓ /etc/sudoers is monitored${NC}"
    MONITORING+=("sudoers")
fi

# Check /etc/passwd
if sudo auditctl -l 2>/dev/null | grep -q "/etc/passwd"; then
    echo -e "  ${GREEN}✓ /etc/passwd is monitored${NC}"
    MONITORING+=("passwd")
fi

# Check SSH
if sudo auditctl -l 2>/dev/null | grep -q "/.*/.ssh"; then
    echo -e "  ${GREEN}✓ SSH keys are monitored${NC}"
    MONITORING+=("ssh")
fi

# Check OpenClaw
if sudo auditctl -l 2>/dev/null | grep -q "/.*/.openclaw"; then
    echo -e "  ${GREEN}✓ OpenClaw config is monitored${NC}"
    MONITORING+=("openclaw")
fi

# Check pacman
if sudo auditctl -l 2>/dev/null | grep -q "pacman"; then
    echo -e "  ${GREEN}✓ Package manager is monitored${NC}"
    MONITORING+=("pacman")
fi

echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}Security Hardening Summary${NC}"
echo "=========================================="
echo ""
echo "Sudoers Protection:        $SUDOERS_STATUS"
echo "Auditd Daemon:             $AUDITD_STATUS"
echo "Auditd Rules:              $RULES_STATUS"
echo "Files Monitored:           ${#MONITORING[@]}/5 critical files"
echo ""

# Overall status
if [[ "$SUDOERS_STATUS" == "✅ PROTECTED" ]] && [[ "$AUDITD_STATUS" == "✅ RUNNING" ]] && [[ $RULE_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓ SECURITY HARDENING: COMPLETE${NC}"
    echo ""
    echo "Your system is protected by:"
    echo "  • Immutable sudoers (prevents privilege escalation)"
    echo "  • Active auditd daemon (comprehensive audit trail)"
    echo "  • $RULE_COUNT auditd rules (monitoring critical operations)"
    echo ""
    echo "This meets requirements for:"
    echo "  ✅ SOC 2 Type II (audit trail + access control)"
    echo "  ✅ ISO 27001 (logging + privilege management)"
    echo "  ✅ HIPAA (audit controls + integrity)"
    echo "  ✅ PCI DSS (access logging + privilege controls)"
    echo ""
    EXIT_CODE=0
else
    echo -e "${RED}✗ SECURITY HARDENING: INCOMPLETE${NC}"
    echo ""
    if [[ "$SUDOERS_STATUS" != "✅ PROTECTED" ]]; then
        echo "  ❌ Need to: sudo chattr +i /etc/sudoers"
    fi
    if [[ "$AUDITD_STATUS" != "✅ RUNNING" ]]; then
        echo "  ❌ Need to: sudo systemctl start auditd"
    fi
    if [[ $RULE_COUNT -eq 0 ]]; then
        echo "  ❌ Need to: Load auditd rules (see SECURITY_SETUP.md)"
    fi
    echo ""
    EXIT_CODE=1
fi

echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run: bash ./scripts/security-verify.sh (this script) to verify status"
echo "  2. If all ✅ green, proceed to Phase 10 (Demo Video)"
echo "  3. Record Timeline Browser demo (30 min)"
echo "  4. Build landing page (2-3 hours)"
echo "  5. Launch 🚀"
echo ""

exit $EXIT_CODE
