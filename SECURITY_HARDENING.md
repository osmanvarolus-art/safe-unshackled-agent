# Security Hardening Checklist

**Date:** 2026-02-15
**Status:** Requires manual intervention (root/sudo)
**Audience:** Deployment team / Osman

---

## Overview

Before public launch of Uncaged, the following security hardening steps must be completed. These cannot be automated via Claude Code (require sudo/root access).

---

## Required Actions (Must Do Before Launch)

### 1. Load auditd Rules for OpenClaw Monitoring

**Current Status:** ❌ No auditd rules loaded
```bash
auditctl -l | wc -l
# Output: 1 (only header, no actual rules)
```

**What to do:**

Create `/etc/audit/rules.d/openclaw.rules`:
```bash
sudo tee /etc/audit/rules.d/openclaw.rules > /dev/null <<'EOF'
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

# Load rules immediately
EOF
```

Then load the rules:
```bash
sudo auditctl -R /etc/audit/rules.d/openclaw.rules
sudo systemctl restart auditd
```

**Verify:**
```bash
auditctl -l | grep openclaw
# Should show all openclaw rules loaded
```

---

### 2. Make /etc/sudoers Immutable

**Current Status:** ❌ Not immutable (vulnerable to tampering)

**What to do:**

Make sudoers immutable so unauthorized changes are blocked:
```bash
sudo chattr +i /etc/sudoers
sudo chattr +i /etc/sudoers.d/
```

**Verify:**
```bash
lsattr /etc/sudoers
# Should show: ----i--------e-- /etc/sudoers
```

**How to undo** (if changes needed):
```bash
sudo chattr -i /etc/sudoers
# Make changes
sudo chattr +i /etc/sudoers
```

---

## What Was Already Done ✅

```bash
✅ GitHub SSH auth configured
✅ Timeline Browser code deployed (640 LOC)
✅ All tests passing (41/41)
✅ Documentation complete
✅ Code committed and pushed to GitHub
```

---

## What Still Needs To Be Done ❌

1. **Security Hardening** ← YOU ARE HERE
   - [ ] Load auditd rules (5 min)
   - [ ] Make sudoers immutable (2 min)

2. **Demo Video** (30 min)
   - [ ] Record 30-second Timeline Browser restore video
   - [ ] Upload to assets (used in landing page)

3. **Landing Page** (2-3 hours)
   - [ ] Design/template: uncaged.dev
   - [ ] Hero section with video
   - [ ] Pricing table (4-tier)
   - [ ] CTA to schedule assessment

4. **Supply Chain Audit 1-Pager** (15 min)
   - [ ] Create PDF one-pager
   - [ ] Host on landing page

---

## Commands Summary (Copy-Paste Ready)

### Load auditd rules:
```bash
sudo tee /etc/audit/rules.d/openclaw.rules > /dev/null <<'EOF'
# OpenClaw Audit Rules
-w /home/.openclaw/ -p wa -k openclaw_config_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes
-w /etc/systemd/system/ -p wa -k systemd_changes
-w /home/.config/systemd/user/ -p wa -k systemd_changes
-w /sbin/auditctl -p x -k audit_tools
-w /sbin/auditd -p x -k audit_tools
-w /home/.ssh/ -p wa -k ssh_key_access
-w /var/log/pacman.log -p wa -k package_changes
EOF

sudo auditctl -R /etc/audit/rules.d/openclaw.rules
sudo systemctl restart auditd
auditctl -l | grep openclaw
```

### Make sudoers immutable:
```bash
sudo chattr +i /etc/sudoers
sudo chattr +i /etc/sudoers.d/
lsattr /etc/sudoers
```

---

## Compliance Alignment

These hardening steps support:
- **SOC 2 Type II:** Immutable audit logs + configuration protection
- **ISO 27001:** Access control (sudoers) + audit trails (auditd)
- **PCI DSS:** Cardholder data protection via egress control
- **HIPAA:** PHI access logging via auditd

---

## After Security Hardening

Once these steps are complete, Uncaged meets minimum security standards for:
- ✅ Preventing unauthorized privilege escalation (immutable sudoers)
- ✅ Comprehensive audit trail (auditd rules loaded)
- ✅ Compliance evidence generation
- ✅ Production-ready deployment

---

**Next Step:** Run the auditd + sudoers commands above, then verify with the commands in each section. Once complete, proceed to Priority 2 (Demo Video).

