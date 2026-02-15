# Uncaged: Give Agents a Padded Cell

**TL;DR:** Autonomous agents are only useful if they have high agency (system access), but that makes your machine fragile. We solved this by making consequences reversible—giving agents a "padded cell" where they can't do permanent damage.

---

## The Problem: Agency vs. Safety

LLMs are powerful tools, but deploying them as agents that can actually *do things* (install packages, modify configs, restart services) creates a fundamental tension:

**Give the agent high agency → it's useful but dangerous.**
**Restrict the agent → it's safe but useless** (spends time hitting permission errors).

Most solutions today force you to pick one:
- **Sandboxes** (Firecracker, Docker) → isolated but slow + session amnesia
- **Permissive** (root access, docker.sock) → fast but one hallucination deletes `/boot`

We chose a third path: **make consequences reversible**.

---

## The Insight: Transactional Rollbacks for Operating Systems

Databases have had transactional rollbacks for 40+ years: **Snapshot → Execute → Validate → Commit/Rollback**.

What if you applied that to OS operations? Agents can run *anything*, but if validation fails, the whole transaction rolls back like it never happened.

1. **Snapshot:** Take a sub-second save point (Btrfs CoW snapshots are mostly metadata pointers).
2. **Execute:** Let the agent run the privileged step it needs.
3. **Validate:** Don't trust exit codes—monitor actual behavior (syscalls, sensitive file access, network egress).
4. **Commit/Rollback:** If anything violates safety policy, rollback instantly to the snapshot.

**Result:** The agent can "do everything," but destructive outcomes don't persist. It's like giving root access inside a Git branch that you can discard if things go wrong.

---

## What This Looks Like in Practice

### Scenario: Typosquatted Package Supply Chain Attack

LLMs hallucinate package names all the time (numpyy, reuqests, sckit-learn). Attackers register these domains and distribute malware.

**Without Uncaged:** Malware persists, credentials exfiltrated, hours of forensics + recovery.

**With Uncaged (Transactional Rollback):**
1. Agent decides to install `numpyy` (typo, malicious package registered)
2. Transactional boundary created (filesystem snapshot taken)
3. Install executed → package runs, tries to exfil credentials to `evil.com`
4. Validation fails:
   - Unauthorized network access detected (blocked by nftables)
   - Malware runs but can't reach C2 (kernel-level egress control)
   - Transaction validation fails
5. Automatic rollback: All changes discarded, filesystem reset to pre-transaction state
6. Audit trail preserved: Full record of what was attempted and blocked
7. Security team investigates with complete visibility

**Result:** Malware never persists. Exfiltration blocked at kernel layer. Recovery in <10 seconds.

**Compare:** Manual cleanup + forensics would take 4-8 hours.

---

## The Uncaged Stack: Four Pillars

### Pillar 1: Btrfs Snapshots (Time Machine)

Copy-on-write filesystems make snapshots cheap—mostly metadata pointer changes, not data copies.

**Why:** Sub-second checkpoint/rollback without cloning whole disks.

**Limitation:** Snapshots are not backups. Disk failure still requires external storage.

### Pillar 2: systemd Namespaces (Local Isolation)

Instead of heavy container overhead or syscall interception, use native Linux namespaces to isolate mount/pid/network scope.

**Why:** Fast startup, real Linux ergonomics, local state persistence.

**Why not Docker:** Socket mounting patterns are insecure; heavy boot tax for frequent snapshots.

### Pillar 3: nftables (Egress Control)

Kernel-level default-deny outbound policy. Even if the agent is "root," secrets can't leave the box to random C2 domains.

**Why:** Prevents exfiltration at OS level—can't be bypassed by userspace exploits.

### Pillar 4: Scoped Privilege (Action-Based Authorization)

Traditional sudo is binary: NOPASSWD = all-powerful. Polkit enables granular permissions: "allow package install," "deny reading /etc/shadow," "allow service restart."

**Why:** Agent utility without giving away total system control.

---

## Why This Beats Existing Options

### vs. Firecracker/microVMs
```
Firecracker:  Strong isolation + latency penalty + session amnesia
Uncaged:      Persistent state + sub-second recovery + local realism
```

### vs. Docker
```
Docker:       Fast containers + insecure socket patterns + permission drift
Uncaged:      Namespace isolation + kernel egress control + fine-grained authz
```

### vs. Traditional Sandboxes
```
Sandboxes:    Maximum safety + agents can't do anything useful
Uncaged:      High agency + bounded blast radius + reversible
```

---

## The Killer Use Case: Slopsquatting Defense

**Slopsquatting:** Attackers register typosquatted package names (`numpyy`, `reuqests`, `sckit-learn`) to distribute malware.

LLMs hallucinate names all the time. In a permissive environment, this is a direct path to compromise.

**Transactional execution turns this into a non-issue:**
- Malware runs but doesn't persist
- Exfiltration blocked at kernel layer
- Automatic rollback + audit trail
- Security team has complete visibility

---

## Implementation: The Timeline Browser Demo

We've shipped a proof-of-concept: **Timeline Browser**, an interactive snapshot browser that demonstrates the full transaction cycle:

```
1. Browse snapshots (see system state at any point in time)
2. Compare snapshots (understand what changed)
3. Restore (transactional action: snapshot → restore → validate → rollback-on-failure)
4. Watch auto-rollback in action (if restore fails, automatic recovery)
```

**Demo:** Corrupt config → Timeline Browser → restore → service running again.
**Time:** 10 seconds.
**Recovery method:** One-click undo.

This is the visual proof that reversibility beats restriction.

---

## What Gets Measured

For engineering teams:
- **Rollback frequency** (instability signal)
- **MTTR** (recovery time; <10 seconds for filesystem state)
- **Audit trail completeness** (100% of privileged ops logged)

For security teams:
- **Blast radius** (filesystem rollback = contained damage)
- **Exfiltration prevention** (egress control at kernel layer)
- **Compliance automation** (audit logs prove containment)

---

## Why Now?

**The market is ready for this because:**

1. **LLM agents are entering production** — ChatGPT-4 with tools, Claude with MCP, custom deployments
2. **Traditional sandboxing is painful** — Docker's insecurity, Firecracker's latency, k8s complexity
3. **Reversibility is a competitive advantage** — agents can move fast without destroying systems
4. **Security auditors love provenance** — "we rolled back; here's the audit log" beats "we think we blocked it"

---

## The Pitch

> We turned the agent safety problem inside out. Instead of trying to prevent every bad action (impossible), we make consequences reversible. Agents get high agency, systems get safety, security teams get audit trails. Recovery time drops from hours to seconds.

---

## Getting Started

**Try it yourself:**
```bash
./scripts/timeline-browser.sh
```

Browse snapshots, compare configs, restore with auto-rollback. This is the demo vehicle for "Transactional Execution."

---

## Next Steps

- **Technical:** Full Uncaged stack (all 9 layers) + hardening guide
- **Product:** Timeline Browser → broader platform
- **Go-to-market:** "Transactional Agency" positioning for enterprises

---

**Uncaged = Agency + Reversibility + Auditability**

The undo button for autonomous agents.

---

*Want to dive deeper? See:*
- *Timeline Browser User Guide: `docs/TIMELINE_BROWSER.md`*
- *Full Implementation Report: `docs/TIMELINE_BROWSER_SUMMARY.md`*
- *Resilience Stack Architecture: `docs/RESILIENCE_STACK.md`*
