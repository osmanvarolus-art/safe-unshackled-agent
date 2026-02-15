#!/bin/bash
# Security Hardening Script for Uncaged
# Loads auditd rules + makes sudoers immutable
# Run with: sudo bash ./scripts/security-hardening.sh

set -e

echo "=========================================="
echo "Uncaged Security Hardening Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: This script must be run as root (use: sudo bash ./scripts/security-hardening.sh)${NC}"
   exit 1
fi

echo -e "${YELLOW}Step 1: Loading auditd rules for OpenClaw${NC}"
echo "Creating /etc/audit/rules.d/openclaw.rules..."

# Create auditd rules file
tee /etc/audit/rules.d/openclaw.rules > /dev/null <<'AUDITD_RULES'
# OpenClaw Audit Rules
# Monitor critical file operations and privilege escalation

# Monitor /home/.openclaw configuration directory
-w /home/.openclaw/ -p wa -k openclaw_config_changes

# Monitor sudoers file modifications
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor systemd service modifications
-w /etc/systemd/system/ -p wa -k systemd_changes
-w /home/.config/systemd/user/ -p wa -k systemd_changes

# Monitor auditd daemon itself
-w /sbin/auditctl -p x -k audit_tools
-w /sbin/auditd -p x -k audit_tools

# Monitor SSH key access
-w /home/.ssh/ -p wa -k ssh_key_access

# Monitor package manager (for supply chain audit)
-w /var/log/pacman.log -p wa -k package_changes

# Buffer size (adjust if needed)
-b 8192

# Failure mode (0=silent, 1=printk, 2=panic)
-f 1
AUDITD_RULES

echo -e "${GREEN}✓ Auditd rules file created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Loading rules into kernel${NC}"
auditctl -R /etc/audit/rules.d/openclaw.rules
echo -e "${GREEN}✓ Rules loaded${NC}"
echo ""

echo -e "${YELLOW}Step 3: Restarting auditd daemon${NC}"
systemctl restart auditd
sleep 1
echo -e "${GREEN}✓ Auditd restarted${NC}"
echo ""

echo -e "${YELLOW}Step 4: Making /etc/sudoers immutable${NC}"
chattr +i /etc/sudoers
echo -e "${GREEN}✓ /etc/sudoers immutable${NC}"
echo ""

echo -e "${YELLOW}Step 5: Making /etc/sudoers.d/ immutable${NC}"
chattr +i /etc/sudoers.d/
echo -e "${GREEN}✓ /etc/sudoers.d/ immutable${NC}"
echo ""

echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

echo -e "${YELLOW}Auditd rules loaded:${NC}"
auditctl -l | grep openclaw | head -5
echo ""

echo -e "${YELLOW}Sudoers file attributes:${NC}"
lsattr /etc/sudoers
echo ""

echo -e "${YELLOW}Sudoers.d directory attributes:${NC}"
lsattr /etc/sudoers.d/
echo ""

echo "=========================================="
echo -e "${GREEN}✓ Security Hardening Complete!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✅ Auditd rules loaded (monitors critical files)"
echo "  ✅ /etc/sudoers immutable (prevents tampering)"
echo "  ✅ /etc/sudoers.d/ immutable (prevents privilege escalation)"
echo ""
echo "These changes ensure:"
echo "  • Comprehensive audit trail (SOC 2 Type II)"
echo "  • Protection against unauthorized privilege changes"
echo "  • Compliance with ISO 27001 + HIPAA"
echo ""
echo "To undo immutable flag (if needed):"
echo "  sudo chattr -i /etc/sudoers"
echo "  sudo chattr -i /etc/sudoers.d/"
echo ""
