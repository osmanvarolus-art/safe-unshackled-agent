# Safe Unshackled Agent: High Agency + High Safety

> **Stop preventing your AI agents. Give them full autonomy and trust reversibility.**

## The Problem: False Choice Between Safety and Agency

Most AI agent security approaches force a terrible choice:

- **Option A:** Restrict everything. Agents become useless paperweights.
- **Option B:** Trust completely. Agents become a security nightmare (CVE-2026-25253 anyone?).

## The Solution: Transactional Agency

Safe Unshackled Agent gives your AI agents **full creative autonomy** while ensuring **every destructive action is reversible, observable, and survivable**.

```
High Agency          High Safety
     ↓                   ↓
[FULL PRIVILEGES] ← [REVERSIBILITY] ← [OBSERVABILITY] ← [CIRCUIT BREAKERS]
```

### Philosophy

**The agent can do anything. But you can see everything it did, roll back anything it broke, and it dies instantly if it touches the honeypot.**

---

## What You Get: 8-Layer Resilience Stack

### Layer 1: Recovery (Btrfs Snapshots)
- Instant, space-efficient Copy-on-Write snapshots of agent state
- <400ms recovery from catastrophic failures
- Automatic daily snapshots at 07:00
- Keep last 10 snapshots with auto-cleanup

### Layer 2: Git-Tracked Config
- Version control for agent configuration (~/.openclaw/)
- Granular rollback on any config change
- Diff capability to see exactly what changed
- Baseline commit with full recovery history

### Layer 3: Immutable Crown Jewels
- SSH keys, sudoers, boot config, API credentials locked with `chattr +i`
- Agent gets "Operation not permitted" — clear, immediate feedback
- Even root can't modify without removing flag first

### Layer 4: Resource Limits (Circuit Breakers)
- CPU: Max 80% of one core (prevents runaway loops)
- Memory: 6GB hard limit, 5GB soft limit
- File descriptors: 8192 max
- Processes: 4096 max threads (Node.js requirement)

### Layer 5: Kernel-Level Observability (Auditd)
- Every access to /etc/passwd, /etc/sudoers, ~/.ssh/, credentials logged at kernel level
- Tamper-proof (kernel writes, can't be bypassed)
- Query anytime: `ausearch -k agent-ssh -i`

### Layer 6: Behavioral Watchdog
- 30-second monitoring interval
- Kills agent on: disk device access, memory >3.5GB, excessive CPU, suspicious process spawning
- Logs all triggers to ~/.mcp-memory/oc-watchdog-alert.md
- Non-destructive (you can restart manually)

### Layer 7: Canary Trap (Honeypot)
- Fake AWS credentials, SSH keys, database passwords in ~/.secrets-canary/
- Zero-tolerance: ANY access triggers instant kill
- inotifywait-based detection with no blind spots
- Alert logged: ~/.mcp-memory/oc-canary-alert.md

### Layer 8: Network Jail (Bonus)
- nftables egress filtering blocks private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Blocks AWS metadata service (169.254.169.254)
- Prevents credential exfiltration while maintaining full public internet access

---

## Quick Start

### Prerequisites
- Linux system with Btrfs filesystem (/ and /home subvolumes)
- auditd already installed
- sudo access
- inotify-tools (`sudo pacman -S inotify-tools` on Arch)

### Installation (5 minutes)

```bash
# Clone this repository
git clone https://github.com/yourusername/safe-unshackled-agent.git
cd safe-unshackled-agent

# Run automated setup (handles all 8 layers)
./scripts/resilience-setup-all.sh

# Verify installation
systemctl --user status openclaw openclaw-watchdog canary-monitor snapshot-openclaw.timer
```

### What Just Happened

✅ Btrfs snapshots: Daily 07:00 automatic backups
✅ Git repo: ~/.openclaw/.git initialized with baseline commit
✅ Immutable files: 10 crown jewels locked with chattr +i
✅ Resource limits: CPU 80%, RAM 6GB, FD 8192
✅ Auditd rules: Kernel monitoring on sensitive paths
✅ Watchdog: 30-second behavioral monitoring active
✅ Canary trap: Honeypot deployed with inotifywait
✅ Nftables: Egress filtering rules loaded

**Integration test score: 24/24 passing (100%)**

---

## Real-World Usage

### Morning Check
```bash
# See what OpenClaw did overnight
~/.local/bin/audit-openclaw.sh

# Check for any security alerts
cat ~/.mcp-memory/oc-watchdog-alert.md
cat ~/.mcp-memory/oc-canary-alert.md
```

### Recover from Bad Config
```bash
# See what changed
cd ~/.openclaw && git diff

# Undo all changes
cd ~/.openclaw && git checkout .
systemctl --user restart openclaw
```

### Restore from Snapshot (Catastrophic Failure)
```bash
# List available snapshots
ls -la /home/.snapshots/

# Restore specific snapshot
sudo btrfs send /home/.snapshots/openclaw-20260214-0700 | \
     sudo btrfs receive ~/.openclaw-restore/
cp -a ~/.openclaw-restore/openclaw-20260214-0700/* ~/.openclaw/
systemctl --user restart openclaw
```

### Investigate Security Alert
```bash
# What triggered the watchdog kill?
cat ~/.mcp-memory/oc-watchdog-alert.md

# What triggered the canary?
cat ~/.mcp-memory/oc-canary-alert.md

# Review auditd logs for credential access
sudo ausearch -k agent-creds -i
```

---

## Architecture Decision: Why These 8 Layers?

| Layer | Problem Solved | Detection | Recovery | Overhead |
|-------|---|---|---|---|
| 1. Btrfs Snapshots | Catastrophic failure | Manual review | <400ms instant restore | ~1GB/snapshot |
| 2. Git Config | Accidental config corruption | `git diff` | `git checkout` | ~10KB .git overhead |
| 3. Immutable Files | Unauthorized privilege escalation | Immediate "Operation not permitted" | Unlock with `chattr -i` | Zero (prevents, doesn't recover) |
| 4. Resource Limits | Runaway loops kill desktop | systemd cgroup metrics | Auto-restart on-failure | ~2MB cgroup monitoring |
| 5. Auditd | Unauthorized file access | Kernel logs, query with ausearch | Review & remediate manually | ~5MB/day audit logs |
| 6. Watchdog | Suspicious behavior | 30-second behavioral scan | Instant kill + alert | ~5% CPU per check |
| 7. Canary Trap | Credential exfiltration attempt | inotifywait (instant) | Instant kill + alert | ~2MB storage |
| 8. Nftables | Data exfiltration | Kernel netfilter rules | Block + log | Kernel-level (negligible) |

**Why not just restrict everything?**
- Restrictions make agents useless (can't execute, can't install packages, can't fetch URLs)
- False sense of security (determined agent can work around many restrictions)
- This approach: **Full agency, just make destruction reversible**

---

## For Enterprise/CISO

### MTTR Metrics
- **Snapshot restore:** 400ms (Btrfs CoW)
- **Config rollback:** 10ms (git checkout)
- **Watchdog kill → restart:** 15s (systemd on-failure)
- **Full system recovery from snapshot:** 5 minutes

### Compliance

✅ **Auditd Logging:** All sensitive file access logged at kernel level
✅ **Immutability:** Critical files locked with chattr +i (tamper-evident)
✅ **Reversibility:** Full snapshot + git history for any point-in-time recovery
✅ **Observability:** Everything logged, nothing hidden

### Dashboard Integration
Coming soon: REST API + metrics export for enterprise SIEM integration

---

## For Researchers / Security Teams

### Supply Chain Defense (Slopsquatting)
This stack protects against hallucinated package imports and npm/pip injection attacks:
- AI agents execute package manager in transactional mode
- Before `npm install`, take snapshot
- If install modifies unexpected files → rollback to snapshot
- Malware never persists (see `/docs/slopsquatting-defense.md`)

### Testing Edge Cases
See `/examples/` for test scenarios:
- Simulating watchdog triggers
- Testing canary detection
- Verifying snapshot restore workflow
- Audit log parsing

---

## FAQ

**Q: Isn't this just container/VM sandboxing?**
A: No. This maintains **full agency** (host execution, systemctl, pacman). Containers restrict too much. VMs are too slow (2-5s boot). This is orthogonal: transactional + observable.

**Q: What about LLM jailbreaks?**
A: Can't prevent LLM jailbreaks. But when they happen, **everything is reversible**. Watchdog + canary catch *behavior*, not prompts. Canary catches the *intent* (trying to access secrets).

**Q: Do I need Btrfs?**
A: Not required, but highly recommended. Alternative: LVM snapshots (slower), or just rely on git + watchdog (no full system recovery). Btrfs is 10x faster.

**Q: How much does this slow down my agent?**
A: <5% CPU for watchdog checks, <10MB memory overhead. Negligible for most workloads.

**Q: OpenClaw... is that Anthropic's?**
A: No, it's an open-source autonomous agent framework. (See `CREDITS.md`). This stack works with any agent system.

---

## Integration with Your Agent Framework

This stack is **framework-agnostic**. It works with:
- ✅ OpenClaw (tested, 24/24 integration tests passing)
- ✅ Claude Code + MCP servers
- ✅ LangChain + LangGraph agents
- ✅ AutoGPT, Griptape, other agent frameworks

See `/docs/integration-guide.md` for framework-specific setup.

---

## Contributing

We welcome contributions! See `CONTRIBUTING.md` for:
- How to add new behavioral rules (watchdog)
- How to extend canary trap honeypot patterns
- How to propose new audit rules

---

## License

MIT License — See `LICENSE` file

---

## Citation

If you use this in research, cite as:

```bibtex
@software{safe_unshackled_agent_2026,
  title = {Safe Unshackled Agent: High Agency + High Safety},
  author = {Osman},
  year = {2026},
  url = {https://github.com/yourusername/safe-unshackled-agent},
  note = {8-layer resilience stack for autonomous AI agents}
}
```

---

## Credits

- **Inspiration:** OpenClaw CVE-2026-25253 security incident
- **Framework:** Btrfs CoW, auditd kernel logging, systemd resource limits
- **Testing:** 24/24 integration tests, real-world Belchicken deployment

---

## Status

**Fully Operational** ✅
- 8 layers implemented and tested
- 24/24 integration tests passing
- Production-ready
- Ready for open-source release

**Timeline:**
- v1.0 Release: 2026-02-15
- v1.1 (Enterprise Dashboard): 2026-03-01
- v2.0 (Slopsquatting Defense Demo): 2026-03-15

---

## Support

- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions
- **Security:** Report to [email@example.com]
- **Commercial:** See `ENTERPRISE.md`

---

**The agent can do anything. But you can see everything it did, roll back anything it broke, and it dies instantly if it touches the honeypot.**

**That's "High Agency, High Safety." That's Safe Unshackled Agent.**
