# Deployment Guide — Safe Unshackled Agent

## Quick Start (5 minutes)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/safe-unshackled-agent.git
cd safe-unshackled-agent

# 2. Run installation (handles all 8 layers)
sudo ./scripts/install.sh

# 3. Verify installation
systemctl --user status openclaw openclaw-watchdog canary-monitor snapshot-openclaw.timer

# 4. Check that all services are running
systemctl --user list-units --type=service --state=running | grep openclaw
```

## What Gets Installed

### Systemd Services (User-level)
- `openclaw-watchdog.service` — Behavioral monitoring (30-second intervals)
- `canary-monitor.service` — Honeypot intrusion detection
- `snapshot-openclaw.timer` — Daily snapshots at 07:00 AM

### Files Modified/Created
- `~/.config/systemd/user/openclaw.service.d/limits.conf` — Resource limits
- `~/.secrets-canary/` — Honeypot files
- `~/.openclaw/.git/` — Git version control
- `/etc/audit/rules.d/openclaw.rules` — Auditd monitoring rules
- `/etc/nftables.d/agent-network-jail.nft` — Network isolation rules

### Resource Limits Applied
- CPU: 80% of one core max
- Memory: 6GB hard limit, 5GB soft limit
- File descriptors: 8,192 max
- Processes/threads: 4,096 max

## Daily Operations

### Morning Check
```bash
# Review overnight activity
./scripts/audit-openclaw.sh

# Check for security alerts
cat ~/.mcp-memory/oc-watchdog-alert.md
cat ~/.mcp-memory/oc-canary-alert.md
```

### Monitor Resource Usage
```bash
# Real-time cgroup monitoring
systemd-cgtop --user --depth=1

# Or check static limits
systemctl --user show openclaw | grep -E 'CPU|Memory|LimitNOFILE'
```

### Emergency: Agent Stops Responding
```bash
# Check why it stopped
journalctl --user -u openclaw -n 50

# Restart it
systemctl --user start openclaw

# Check if watchdog or canary killed it
cat ~/.mcp-memory/oc-watchdog-alert.md
cat ~/.mcp-memory/oc-canary-alert.md
```

## Recovery Workflows

### Recover from Bad Configuration (Git)
```bash
# See what changed
cd ~/.openclaw && git diff

# Revert all changes
cd ~/.openclaw && git checkout .

# Restart agent
systemctl --user restart openclaw
```

### Recover from System Failure (Btrfs Snapshot)
```bash
# List available snapshots
ls -la /home/.snapshots/

# Restore specific snapshot
sudo btrfs send /home/.snapshots/openclaw-20260214-0700 | \
     sudo btrfs receive ~/.openclaw-restore/

# Copy files back
cp -a ~/.openclaw-restore/openclaw-20260214-0700/* ~/.openclaw/

# Restart agent
systemctl --user restart openclaw
```

### Investigate Audit Logs
```bash
# SSH key access
sudo ausearch -k agent-ssh -i

# Credential access
sudo ausearch -k agent-creds -i

# Package manager execution
sudo ausearch -k agent-pacman -i

# Date range query
sudo ausearch -k agent-ssh --start 2026-02-14 --end 2026-02-15 -i
```

## Troubleshooting

### Watchdog Keeps Killing Agent
**Problem:** Agent is being killed every 30 seconds
**Solution:** Check what triggered it
```bash
cat ~/.mcp-memory/oc-watchdog-alert.md
```
**Common causes:**
- Memory usage > 3.5GB (check with `systemd-cgtop`)
- Too many child processes (fork bomb detection)

**Fix:**
```bash
# Increase memory limit temporarily
systemctl --user edit openclaw
# Change MemoryMax=6G to MemoryMax=8G
systemctl --user daemon-reload
systemctl --user restart openclaw
```

### Canary Trap Triggered (Agent Accessed Honeypot)
**Problem:** Agent was killed by canary monitor
**Solution:** Check what it was trying to access
```bash
cat ~/.mcp-memory/oc-canary-alert.md
```

**This is intentional.** The canary is set to zero-tolerance. If your agent legitimately needs to access secrets:
1. Move real secrets elsewhere (use proper secret management)
2. Remove files from ~/.secrets-canary/
3. Restart: `systemctl --user start openclaw`

### Immutable File Locked (Operation Not Permitted)
**Problem:** "Operation not permitted" when trying to modify protected file
**Solution:** This is working as designed. To modify:
```bash
# Remove immutable flag
sudo chattr -i /path/to/file

# Make changes
sudo nano /path/to/file

# Re-lock
sudo chattr +i /path/to/file

# Verify
lsattr /path/to/file
```

## Security Checklist

- [ ] All 8 layers installed (`sudo ./scripts/install.sh`)
- [ ] Systemd services running (`systemctl --user status openclaw-watchdog`)
- [ ] Snapshots enabled (`ls -la /home/.snapshots/`)
- [ ] Git repo initialized (`cd ~/.openclaw && git log`)
- [ ] Immutable files locked (`lsattr ~/.ssh/id_rsa`)
- [ ] Auditd rules loaded (`sudo auditctl -l | grep agent-`)
- [ ] Nftables rules active (`sudo nft list ruleset`)

## Performance Considerations

### Expected Overhead
- **CPU:** 5% per watchdog check (30-second interval = negligible)
- **Memory:** ~10MB for monitoring services
- **Disk:** ~1GB per snapshot (space-efficient CoW)
- **Network:** No overhead (firewall rules are kernel-level)

### Monitoring Commands
```bash
# Memory usage
free -h

# Disk usage
df -h /home/.snapshots/

# CPU usage
top -p $(pgrep -f openclaw)

# Network rules
sudo nft list ruleset
```

## Maintenance

### Monthly Tasks
- [ ] Review audit logs for patterns
- [ ] Check snapshot retention (keeps last 10)
- [ ] Verify git history is building
- [ ] Monitor disk space

### Quarterly Tasks
- [ ] Test snapshot restore workflow
- [ ] Test git rollback
- [ ] Review and update canary trap patterns
- [ ] Check for new security advisories

## Enterprise Deployment

### Multiple Agents
Each agent gets its own stack:
```bash
# Agent 1
sudo AGENT_USER=agent1 ./scripts/install.sh

# Agent 2
sudo AGENT_USER=agent2 ./scripts/install.sh
```

### SIEM Integration
Coming soon: REST API for metrics export and alert forwarding

### Compliance
- ✅ Auditd logging (immutable, kernel-level)
- ✅ File integrity (chattr +i on critical files)
- ✅ Resource isolation (systemd cgroups)
- ✅ Recovery capability (Btrfs snapshots + git)

## Support

- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions
- **Documentation:** See `/docs/`

---

**You're now running Safe Unshackled Agent. Your agent has full autonomy with built-in safety nets. Welcome to the future of AI agent deployment.** 🚀
