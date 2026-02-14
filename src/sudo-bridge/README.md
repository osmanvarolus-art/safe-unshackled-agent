# Scoped Sudo Bridge — Layer 3b: Agent Power Without Root Risk

**Status:** Production-ready
**Version:** 1.0
**Date:** 2026-02-15

## Overview

The Scoped Sudo Bridge is a privilege escalation daemon that allows autonomous AI agents to perform privileged operations (service restarts, package installations, etc.) while maintaining:

- **Whitelist enforcement** (only pre-approved operations)
- **Full auditability** (every call is logged)
- **Shell injection prevention** (safe argument handling)
- **Rate limiting** (prevent brute-force escalation)

## Problem It Solves

Without Sudo Bridge:
```
Agent: $ sudo systemctl restart redis
Result: sudo: no password entry for user "agent"
Impact: Agent can't perform legitimate privileged operations
```

With Sudo Bridge:
```
Agent: $ uncaged-sudo systemctl restart redis
Daemon checks whitelist → allows systemctl restart redis
Result: ✓ Service restarts, operation audited
Impact: Agent has power while remaining controlled
```

## Architecture

```
Agent Process (UID 1000)
    ↓
/opt/uncaged/sudo-bridge.sh systemctl restart redis
    ↓
/opt/uncaged/sudo-bridge-daemon.sh (runs as root)
    ├─ Load whitelist.json
    ├─ Validate: "systemctl" is whitelisted? ✓
    ├─ Validate: "restart" is allowed? ✓
    ├─ Validate: "redis" is allowed target? ✓
    ├─ Validate: Rate limit OK? ✓
    ├─ Validate: Shell injection safe? ✓
    └─ Execute: /usr/bin/systemctl restart redis
       └─ Log operation to auditd
```

## Installation

### Prerequisites
- Arch Linux (pacman) or similar
- Root access (sudo)
- jq (JSON processor)
- auditd (audit daemon)

### Quick Install

```bash
# Install jq if needed
sudo pacman -S jq audit

# Deploy sudo-bridge
sudo ~/.openclaw/sudo-bridge/install-sudo-bridge.sh

# Verify
uncaged-sudo systemctl status auditd
```

### What Gets Installed

```
/opt/uncaged/
├── sudo-bridge.sh              # Wrapper (agent calls this)
├── sudo-bridge-daemon.sh       # Daemon (runs as root)
├── config/
│   ├── whitelist.json          # Allowed operations
│   ├── sudo-bridge.log         # Operation log
│   └── auditd.rules            # Audit configuration
└── systemd/
    └── sudo-bridge.service     # Systemd service

/etc/audit/rules.d/
└── sudo-bridge.rules           # Auditd rules (loaded)

/etc/systemd/system/
└── sudo-bridge.service         # Systemd service (enabled)

/usr/local/bin/
└── uncaged-sudo                # Convenience alias
```

## Usage

### Basic Usage

```bash
# Service management
uncaged-sudo systemctl restart nginx
uncaged-sudo systemctl stop redis
uncaged-sudo systemctl enable postgres

# Package installation
uncaged-sudo pacman -S nodejs
uncaged-sudo pacman -Syu

# Check status
uncaged-sudo systemctl status openclaw
```

### Check Logs

```bash
# View daemon log
sudo tail -f /opt/uncaged/config/sudo-bridge.log

# View auditd logs
sudo ausearch -k sudo-bridge-exec -i

# Search by operation
sudo ausearch -k sudo-bridge-config -i
```

### Modify Whitelist

```bash
# Edit whitelist
sudo nano /opt/uncaged/config/whitelist.json

# Changes are hot-loaded on next request
```

## Whitelist Format

```json
{
  "systemctl": {
    "description": "System service management",
    "allowed_actions": ["start", "stop", "restart", "reload"],
    "allowed_targets": ["nginx", "redis", "postgres"],
    "audit": true,
    "require_reason": false
  },
  "pacman": {
    "description": "Package management",
    "allowed_actions": ["-S", "-Syu"],
    "allowed_packages": ["nodejs", "python3", "git"],
    "audit": true,
    "require_reason": true
  }
}
```

## Security Mechanisms

### 1. Whitelist Validation

Every operation is checked against whitelist:
- Command must exist in whitelist
- Action must be in `allowed_actions`
- Target must be in `allowed_targets` (if specified)

### 2. Shell Injection Prevention

All arguments checked for shell metacharacters:
```bash
# Blocked: Agent can't do this
uncaged-sudo systemctl restart "redis; rm -rf /"
               ↑
           Shell metacharacters detected → DENIED
```

### 3. Rate Limiting

Prevents brute-force escalation:
```
Max 30 operations per minute per user
If exceeded: Operation DENIED + logged
```

### 4. Auditd Integration

All operations logged at kernel level:
```bash
$ sudo ausearch -k sudo-bridge-exec -i

type=EXECVE msg=audit(...): argc=3
a0="/opt/uncaged/sudo-bridge-daemon.sh"
a1="systemctl"
a2="restart"
a3="redis"
key=sudo-bridge-exec
uid=1000 (agent)
timestamp=2026-02-15T15:30:22.123
```

## Design Philosophy

### Principle of Least Privilege

Only allow operations that are necessary:
- ✅ Start/stop services (agent needs this)
- ✅ Install packages (agent needs this)
- ❌ Delete files (use git for rollback)
- ❌ Modify sudoers (immutable files protect this)
- ❌ Mount filesystems (high security risk)

### Defense Layers

```
Agent wants to escalate privilege
    ↓
Layer 1: Whitelist check
    └─→ Command not in whitelist? DENY
        ↓
Layer 2: Action validation
    └─→ Action not allowed? DENY
        ↓
Layer 3: Target validation
    └─→ Target not in whitelist? DENY
        ↓
Layer 4: Rate limiting
    └─→ Too many operations? DENY
        ↓
Layer 5: Shell injection check
    └─→ Dangerous characters? DENY
        ↓
Layer 6: Auditd logging
    └─→ Log before execution
        ↓
Layer 7: Execute (if all checks pass)
    └─→ Run the operation
```

## Failure Modes

### What If Daemon Crashes?

```
Graceful failure:
• Service auto-restarts (Restart=on-failure)
• Agent gets error message
• Operation is logged
• No damage is done (execution never happened)
```

### What If Whitelist Is Corrupted?

```
Safe state:
• Daemon checks JSON syntax on load
• Invalid JSON → all operations DENIED
• Safe default: whitelist required to proceed
```

### What If Auditd Fails?

```
Operation still logged to:
• Daemon log file (/opt/uncaged/config/sudo-bridge.log)
• Auditd (if available)
• Syslog (journalctl)

Multiple redundant logs ensure no operations are hidden
```

## Performance

```
Overhead per operation:
├── Whitelist load: ~5ms
├── JSON validation: ~10ms
├── Rate limit check: ~2ms
├── Shell injection check: <1ms
└── Execution: <100ms (varies by command)
   TOTAL: ~120ms (negligible for agent operations)
```

## Compliance & Audit

### What Gets Logged?

```
✓ Every escalation attempt (allowed or denied)
✓ Operation details (command, action, target)
✓ Caller ID (UID, PID)
✓ Timestamp
✓ Result (success/failure)
✓ Shell injection attempts
✓ Rate limit violations
✓ Whitelist errors
```

### Audit Trail Example

```
[2026-02-15T15:30:22.123] [SUCCESS] UID=1000 PID=12345: systemctl restart nginx
[2026-02-15T15:30:45.456] [DENIED] UID=1000 PID=12346: rm -rf / (shell injection)
[2026-02-15T15:31:10.789] [DENIED] UID=1000 PID=12347: chattr -i /etc/sudoers (blocked)
```

## Troubleshooting

### Agent Can't Call Sudo Bridge

**Problem:** `command not found: uncaged-sudo`

**Solution:**
```bash
# Check if installed
ls -la /usr/local/bin/uncaged-sudo

# If missing, reinstall
sudo ~/.openclaw/sudo-bridge/install-sudo-bridge.sh

# Or call directly
/opt/uncaged/sudo-bridge.sh systemctl restart nginx
```

### Operation Denied Unexpectedly

**Problem:** `Command not whitelisted: systemctl`

**Solution:**
```bash
# Check whitelist
cat /opt/uncaged/config/whitelist.json | jq .

# Verify JSON syntax
jq . /opt/uncaged/config/whitelist.json

# Check logs
sudo tail -50 /opt/uncaged/config/sudo-bridge.log
```

### Rate Limited

**Problem:** `Rate limit exceeded for UID=1000 (35 operations)`

**Solution:**
```bash
# Wait a minute (rate limit is per-minute)
# Or increase limit in sudo-bridge-daemon.sh

# Check recent operations
sudo grep "UID=1000" /opt/uncaged/config/sudo-bridge.log | tail -30
```

## Integration with Layers 1-8

### Layer 1: Btrfs Snapshots
```
Snapshot created before operation
  ↓
Agent calls uncaged-sudo systemctl restart service
  ↓
Daemon validates and executes
  ↓
If operation breaks something:
  ↓
Restore from snapshot in <400ms
```

### Layer 5: Auditd Monitoring
```
Auditd monitors: /opt/uncaged/sudo-bridge-daemon.sh (execute)
  ↓
Every call logged in auditd kernel log
  ↓
Correlate with openslaw audit trail:
  $ sudo ausearch -k sudo-bridge -i --start recent
```

### Layer 3: Immutable Files
```
Whitelist prevents: chattr -i /etc/sudoers
  ↓
Even if daemon is compromised, sudoers stays protected
  ↓
Immutable flag blocks removal of protection
```

## Future Enhancements

- [ ] Systemd socket activation (more secure)
- [ ] Namespace isolation for executed commands
- [ ] Time-based rate limiting (token bucket)
- [ ] Command output filtering (hide sensitive data)
- [ ] Encrypted audit logs
- [ ] SIEM integration (send to central logging)

## Security Considerations

### Assumptions

- Daemon runs as root (necessary for privilege escalation)
- Whitelist file is not world-writable (protection via filesystem)
- auditd is running (for tamper-proof logging)
- Kernel is not compromised (assumes trusted kernel)

### Threat Model

```
Attacker Goal: Execute privileged operation without whitelist

Scenario 1: Modify whitelist.json
├─ Auditd detects write to config file
├─ Daemon loads whitelist on each request
└─ Change takes effect immediately (no restart needed)
   → Mitigation: Monitor /etc/audit/rules.d/sudo-bridge.rules

Scenario 2: Disable auditd
├─ Daemon continues logging to file
├─ Syslog still captures logs
├─ Canary trap catches credential theft
└─ Watchdog detects suspicious behavior
   → No single point of failure

Scenario 3: Compromise sudo-bridge daemon
├─ Still must execute as daemon's UID
├─ Auditd logs all execution
├─ Immutable files still protected
├─ Agent's activity is bounded by resource limits
└─ Watchdog detects anomalous behavior
   → Defense in depth
```

## License

MIT License — See root LICENSE file

## Support

- **Issues:** GitHub Issues
- **Documentation:** See docs/
- **Logs:** /opt/uncaged/config/sudo-bridge.log
