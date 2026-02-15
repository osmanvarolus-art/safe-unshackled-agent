# Security Hardening Setup Instructions

**Status:** Ready to execute
**Time Required:** 7 minutes
**Privilege Required:** sudo (root)

---

## What This Script Does

1. **Creates auditd rules file** (`/etc/audit/rules.d/openclaw.rules`)
   - Monitors OpenClaw config changes
   - Monitors sudoers modifications
   - Monitors SSH key access
   - Monitors package manager (supply chain audit)

2. **Loads rules into kernel** (makes audit trail active)
   - Loads via `auditctl -R`
   - Restarts auditd daemon
   - Rules persist across reboots

3. **Makes sudoers immutable** (prevents privilege escalation)
   - Sets `+i` flag on `/etc/sudoers`
   - Sets `+i` flag on `/etc/sudoers.d/`
   - Prevents unauthorized sudo rule changes
   - Can only be removed by root with `chattr -i`

---

## How to Run

### Option A: Automated (Recommended)

```bash
cd /home/osman/Projects/safe-unshackled-agent
sudo bash ./scripts/security-hardening.sh
```

**Expected output:**
```
==========================================
Uncaged Security Hardening Script
==========================================

Step 1: Loading auditd rules for OpenClaw
Creating /etc/audit/rules.d/openclaw.rules...
✓ Auditd rules file created

Step 2: Loading rules into kernel
✓ Rules loaded

Step 3: Restarting auditd daemon
✓ Auditd restarted

Step 4: Making /etc/sudoers immutable
✓ /etc/sudoers immutable

Step 5: Making /etc/sudoers.d/ immutable
✓ /etc/sudoers.d/ immutable

==========================================
Verification
==========================================

Auditd rules loaded:
-w /home/.openclaw/ -p wa -k openclaw_config_changes
-w /etc/sudoers -p wa -k sudoers_changes
[... more rules ...]

Sudoers file attributes:
----i--------e-- /etc/sudoers

Sudoers.d directory attributes:
----i--------e-- /etc/sudoers.d

==========================================
✓ Security Hardening Complete!
==========================================
```

---

### Option B: Manual (If Script Fails)

If the script encounters issues, you can run these commands manually:

**Step 1: Create auditd rules**
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
-b 8192
-f 1
EOF
```

**Step 2: Load rules**
```bash
sudo auditctl -R /etc/audit/rules.d/openclaw.rules
sudo systemctl restart auditd
```

**Step 3: Make sudoers immutable**
```bash
sudo chattr +i /etc/sudoers
sudo chattr +i /etc/sudoers.d/
```

**Step 4: Verify**
```bash
auditctl -l | grep openclaw
lsattr /etc/sudoers
```

---

## Verification (Run After)

### Check Auditd Rules Loaded

```bash
auditctl -l | grep openclaw
```

**Expected:** Should show all 9 openclaw rules

```bash
-w /home/.openclaw/ -p wa -k openclaw_config_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes
-w /etc/systemd/system/ -p wa -k systemd_changes
-w /home/.config/systemd/user/ -p wa -k systemd_changes
-w /sbin/auditctl -p x -k audit_tools
-w /sbin/auditd -p x -k audit_tools
-w /home/.ssh/ -p wa -k ssh_key_access
-w /var/log/pacman.log -p wa -k package_changes
```

### Check Sudoers Immutable

```bash
lsattr /etc/sudoers
```

**Expected:** Should show `i` flag:
```bash
----i--------e-- /etc/sudoers
```

### Check Auditd is Running

```bash
systemctl status auditd
```

**Expected:** Should show `active (running)`

### View Recent Audit Events

```bash
sudo ausearch -k openclaw_config_changes
```

**Expected:** Shows any changes to `/home/.openclaw/`

---

## What Changes This Makes

### System State Before
```
auditctl -l → (empty or default rules only)
lsattr /etc/sudoers → (no immutable flag)
systemctl status auditd → (may be inactive)
```

### System State After
```
auditctl -l → (9 openclaw rules loaded)
lsattr /etc/sudoers → ----i--------e--
systemctl status auditd → active (running)
```

---

## If You Need to Undo

### Remove Immutable Flag (if needed to edit sudoers)

```bash
sudo chattr -i /etc/sudoers
# Make your changes
sudo chattr +i /etc/sudoers
```

### Remove Auditd Rules

```bash
sudo rm /etc/audit/rules.d/openclaw.rules
sudo auditctl -D  # Delete all rules
sudo systemctl restart auditd
```

---

## Compliance Impact

These changes enable:

✅ **SOC 2 Type II**
- Comprehensive audit logging
- Automated audit trail
- Evidence of access controls

✅ **ISO 27001**
- A.12.4 Logging requirement
- A.12.2.1 Access rights management
- A.14.2.1 Secure development

✅ **HIPAA**
- Audit controls (PHI access logging)
- Access controls (privilege management)
- Integrity controls (immutable sudoers)

✅ **PCI DSS**
- Requirement 10 (audit logging)
- Requirement 12 (privilege management)

---

## Troubleshooting

### "chattr: command not found"
```bash
# Install e2fsprogs (if missing)
sudo pacman -S e2fsprogs
```

### "auditctl: command not found"
```bash
# Install audit package (if missing)
sudo pacman -S audit
```

### "Permission denied" on auditctl
```bash
# Make sure you're running with sudo
sudo bash ./scripts/security-hardening.sh
```

### Script hangs on "auditctl -R"
```bash
# Kill any existing auditctl process
sudo pkill -f auditctl
# Try again
sudo bash ./scripts/security-hardening.sh
```

### Sudoers is already immutable
```bash
# This is OK! Just verify:
lsattr /etc/sudoers
# Shows: ----i--------e--
```

---

## Next Steps

After running this script:

1. ✅ **Security hardening complete** (7 min)
2. 📹 **Record demo video** (30 min)
   - Launch Timeline Browser
   - Browse → Diff → Restore
   - Save 30-second highlight reel
3. 🌐 **Build landing page** (2-3 hours)
   - uncaged.dev domain
   - Hero + pricing + CTA
4. 🚀 **Launch** (send HN post + outreach)

---

## Questions?

See:
- `DEPLOYMENT_STATUS.md` - Full deployment status
- `SECURITY_HARDENING.md` - Detailed explanation
- `README_MASTER.md` - Central documentation hub

