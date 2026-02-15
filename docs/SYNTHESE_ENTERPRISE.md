# Uncaged: Resilient Agent Infrastructure for Autonomous Operations

**EXECUTIVE SUMMARY**

Organizations deploying autonomous agents for production workloads face an acute trade-off: operational utility versus risk containment. Traditional sandboxing approaches (containerization, microVM isolation, capability restriction) reduce attack surface at the cost of agent effectiveness and operational responsiveness. Permissive deployment models enable full agent functionality but sacrifice auditability and recovery guarantees.

Uncaged resolves this through **transactional execution architecture**, applying database transaction semantics to operating system operations. All privileged agent actions execute within bounded transaction boundaries with automatic rollback on validation failure, comprehensive audit logging, and sub-second recovery time.

**Key Benefit:** Recovery time from 4-8 hours (manual intervention, forensics, restoration) to 5-10 seconds (automated rollback + audit trail review).

---

## Operational Model

### Transaction Lifecycle

All privileged operations follow a deterministic transaction boundary:

```
CHECKPOINT → EXECUTE → VALIDATE → COMMIT/ROLLBACK
```

**Phase 1: Checkpoint**
- Filesystem snapshot created (Btrfs copy-on-write)
- Current system state recorded as baseline
- Operation metadata logged to audit queue
- Execution permission verified via Polkit (scoped authorization)

**Phase 2: Execute**
- Agent operation runs within transaction boundary
- All system calls monitored via auditd
- File modifications tracked
- Network operations subject to kernel-level filtering

**Phase 3: Validate**
- Service health verification (systemd status checks)
- Audit log inspection for policy violations
- Egress filtering validation (nftables rule enforcement)
- Custom health check execution (optional)

**Phase 4: Commit/Rollback**
- **On success:** Transaction committed, snapshot retained for historical audit
- **On failure:** Automatic rollback to pre-transaction snapshot, audit trail preserved, operator notified
- All outcomes logged with audit trail

---

## Technical Architecture

### Layer 1: Filesystem Checkpointing (Btrfs CoW)

**Technology:** Btrfs copy-on-write snapshots

**Operational characteristics:**
- Snapshot creation: <100ms (metadata-only for initial snapshot)
- Rollback time: 1-5 seconds (depends on delta size)
- Storage efficiency: Only changed blocks consume storage

**Constraints:**
- Requires Btrfs filesystem (not BTRFS raid; single-volume recommended)
- Snapshots are point-in-time filesystem state only (not full system state)
- Kernel-level changes (loaded modules, network stack state) may persist post-rollback

**Audit integration:**
- Snapshot naming convention: `openclaw-YYYYMMDD-HHMMSS`
- Snapshots retained per retention policy (default: keep 10, ~7 days)
- Emergency backups created before high-risk operations

### Layer 2: Execution Isolation (systemd Namespaces)

**Technology:** Linux namespace isolation (PID, mount, network, user)

**Operational characteristics:**
- Startup latency: Negligible (native systemd units, no VM overhead)
- Isolation scope: Mount tree, process tree, network interfaces
- State persistence: Local agent state retained across isolation boundaries

**Constraints:**
- Kernel API still accessible (namespace isolation ≠ syscall whitelist)
- Shared kernel = shared privilege escalation risks
- Not suitable for untrusted code execution (threat model is "agent with correct API, possible input injection")

**Audit integration:**
- systemd journal captures all namespace transitions
- Process lineage logged for forensics
- Failed operations generate alerts

### Layer 3: Network Isolation (nftables Default-Deny)

**Technology:** nftables kernel-level stateful filtering

**Operational characteristics:**
- Default policy: Deny all outbound traffic except explicitly allowed
- Allowed destinations: Configurable per operation (e.g., "npm registry," "GitHub API")
- Private network blocking: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 blocked by default

**Constraints:**
- Requires Linux 4.18+ (nftables kernel support)
- DNS exfiltration prevention requires DNS policy (not automatic)
- VPN/proxy configurations may require policy updates

**Audit integration:**
- All dropped packets logged via nftables counters
- Connection attempts to blocked destinations trigger alerts
- Policy violations generate security events

### Layer 4: Privilege Scoping (Polkit Action-Based Authorization)

**Technology:** Polkit (formerly PolicyKit) action definitions

**Operational characteristics:**
- Authorization granularity: Per-action (e.g., "org.uncaged.package.install")
- Decision model: Action-based (not role-based)
- Interactive flow: Can require user confirmation, OTP, or scriptable approval

**Constraints:**
- Requires user-level polkit daemon
- Passwords can be cached (configure session timeout for security)
- Custom actions require policy definition files

**Audit integration:**
- All authorization decisions logged to audit trail
- Denied attempts trigger alerts
- Action execution tracked with user/timestamp/result

### Layer 5: Kernel-Level Audit (auditd)

**Technology:** Linux kernel audit subsystem

**Operational characteristics:**
- Audit mode: Immutable (cannot disable without reboot)
- Log destination: auditd daemon, persisted to disk
- Coverage: File access, system calls (configurable), privilege escalation

**Constraints:**
- Audit logs can grow rapidly (requires log rotation policy)
- Some syscalls have non-deterministic ordering (log parsing requires care)
- High-frequency auditing can impact performance

**Audit integration:**
- All file modifications logged with inode, timestamp, process lineage
- Sensitive file access (SSH keys, /etc/sudoers) flagged immediately
- Unauthorized privilege escalation attempts blocked + logged

---

## Operational Guarantees

### Safety Guarantees

**G1: Atomic Rollback**
- All filesystem changes rolled back to pre-transaction snapshot
- Guarantee: Zero partial modifications on failed transaction
- Rollback latency: 1-5 seconds
- Limitation: Kernel memory state not rolled back; reboot may be required for kernel-level exploits

**G2: Network Isolation**
- All outbound connections not explicitly whitelisted are blocked at kernel layer
- Guarantee: Exfiltration impossible without defeating nftables rules (kernel-level)
- Whitelisting: Per-operation (e.g., "npm install" can reach npm registry only)
- Limitation: DNS leaks if resolver not configured with firewall rules

**G3: Audit Trail Completeness**
- All privileged operations logged to immutable audit trail
- Guarantee: Cannot disable auditing without system reboot
- Retention: Configurable (default: 10 days / 500MB max)
- Limitation: Audit daemon can be killed (triggers alert; audit messages buffer in kernel)

**G4: Privilege Scoping**
- Agent can only execute actions explicitly whitelisted in Polkit policy
- Guarantee: Escalation attempts outside policy are blocked
- Fallback: If Polkit unavailable, action denied (fail-safe)
- Limitation: Polkit policy files are editable by root

### Operational Guarantees

**O1: Recovery Time (MTTR)**
- Filesystem state recovery: <10 seconds (snapshot rollback)
- Service state recovery: <30 seconds (systemd service restart)
- Total transaction cycle time: <5 minutes (typical)
- Best case: <10 seconds (filesystem rollback only)
- Worst case: Manual recovery required (kernel-level exploit, non-filesystem damage)

**O2: Auditability**
- 100% of privileged operations logged with:
  - Timestamp (nanosecond precision)
  - Process lineage (parent process IDs)
  - Action (specific operation attempted)
  - Result (success/failure + reason)
  - User context (who triggered the operation)

**O3: State Consistency**
- Filesystem state guaranteed consistent post-rollback
- Service health verified before transaction commit
- Custom validators can enforce domain-specific consistency

---

## Compliance Characteristics

### Regulatory Alignment

**SOC 2 Type II**
- ✅ Audit trail requirement: All operations logged + immutable
- ✅ Incident response: Automated rollback + documented recovery
- ✅ Change management: All changes logged; unauthorized changes rolled back
- ✅ Configuration management: Snapshot-based baseline + audit trail

**ISO 27001**
- ✅ A.12.4 (Logging): Comprehensive audit logs with retention
- ✅ A.12.2.1 (User registration and access rights): Polkit action-based access control
- ✅ A.14.2.1 (Secure development policy): Transaction boundary enforces validation gates
- ✅ A.12.3.1 (Information security event logging): All security events logged

**PCI DSS 4.0**
- ✅ Requirement 3: Stored cardholder data protected via network isolation
- ✅ Requirement 10: All access to cardholder data logged with full audit trail
- ✅ Requirement 12.2: Privilege management via action-based Polkit authorization

**HIPAA**
- ✅ Audit controls: Comprehensive logging of PHI access
- ✅ Integrity controls: Rollback prevents unauthorized modifications
- ✅ Access controls: Scoped authorization prevents over-privileged operations

### Evidence Generation

**Compliance artifacts:**
1. **Audit Log Export:** All operations with timestamps, actors, outcomes (exportable to SIEM)
2. **Rollback Report:** Automatic incident response documentation
3. **Policy Attestation:** Signed Polkit policies defining allowed actions
4. **Recovery Time Metrics:** Historical MTTR data for SLA compliance

---

## Deployment Model

### Minimal Deployment

```
Agent Service (systemd)
  ↓ (namespaced)
Filesystem (Btrfs snapshot-enabled)
  ↓ (guarded by)
nftables (egress control)
  ↓ (authorized by)
Polkit (action policy)
  ↓ (monitored by)
auditd (immutable logging)
```

**Hardware requirements:**
- Btrfs filesystem (single volume or pool)
- Linux 4.18+ (nftables support)
- auditd installed
- Polkit daemon running
- ~500MB disk for snapshot retention

**Startup time:** <30 seconds (systemd units)
**Operational overhead:** <5% CPU (auditd logging), disk I/O proportional to audit volume

### Enterprise Deployment

```
Multi-agent cluster
  ↓
Shared Btrfs pool (with replication to cold storage)
  ↓
Centralized nftables policy server
  ↓
Centralized Polkit authorization
  ↓
SIEM integration (Splunk/ELK for audit logs)
  ↓
Compliance dashboard (rollback metrics, policy violations)
```

**Optional integrations:**
- External audit log archival (S3, Azure Blob, SFTP)
- Automated incident response (Slack/PagerDuty on rollback)
- Compliance reporting (automated SOC 2/ISO 27001 evidence generation)

---

## Risk Analysis & Limitations

### Accepted Risks

**R1: Kernel-Level Exploits**
- Risk: Kernel vulnerability allows privilege escalation, bypassing all userspace controls
- Mitigation: Namespace isolation + auditd monitoring + rapid patching
- Assumption: Kernel security patches applied within 24-48 hours of release

**R2: Zero-Day Supply Chain Attack**
- Risk: Malicious package installed before signature/policy can catch it
- Mitigation: Transactional execution allows rollback before damage persists; network isolation blocks exfiltration
- Assumption: Validation layer (scanning, heuristics) in place before execution phase

**R3: Persistent Backdoors**
- Risk: Malware installs kernel module or systemd unit persisting post-rollback
- Mitigation: Auditd catches systemd file modifications; kernel module loading monitored
- Assumption: Validate all syscalls for suspicious activity patterns

### Known Limitations

**L1: Kernel State**
- Limitation: Kernel memory state not rolled back (loaded modules, network stack state persists)
- Workaround: Reboot if kernel exploit suspected
- Impact: Rare; most agent operations don't require kernel modification

**L2: External State**
- Limitation: API calls to external systems not rolled back (e.g., package registry upload)
- Workaround: Pre-transaction validation prevents external operations until approval
- Impact: Not applicable to read-only agent operations

**L3: Performance Impact**
- Limitation: Snapshot creation + auditd logging add 5-10% overhead
- Workaround: Tune audit rules to exclude high-frequency syscalls
- Impact: Negligible for I/O-bound operations; measurable for CPU-intensive workloads

---

## Pricing & Commercial Model

### Value Delivery

**Time saved per incident:** 6-8 hours (MTTR reduction)
**Risk mitigation:** Blast radius containment + audit evidence
**Compliance automation:** SOC 2 audit costs reduced 30-40%

### Offer Ladder

1. **Quick Risk Scan** (€490) — 1-day assessment
   - Architecture review
   - Timeline Browser demo (proof of transactional rollback)
   - Risk report + recommendations

2. **Supply Chain Audit** (€2,500 + €199/month) — Dependency security
   - Deep audit of agent dependencies (npm, PyPI, etc.)
   - Typosquatting risk assessment
   - Rollback simulation + testing
   - Ongoing supply chain monitoring (recurring)
   - Remediation plan + hardening guide
   - **Key benefit:** Protection against hallucinated package names

3. **Hardened Setup Sprint** (€3,000) — 5-day implementation
   - Deploy full Uncaged stack
   - Configure Polkit policies for agent constraints
   - Integration with existing agent platform
   - Demo to security/compliance teams
   - Includes transactional rollback validation

4. **Runtime Care** (€39/month or €199/month) — Ongoing monitoring
   - Continuous audit log analysis
   - Rollback frequency KPI tracking
   - Policy updates + threat response
   - Optional supply chain monitoring (€199/month tier)
   - Compliance reporting

5. **Enterprise Custom** (€12K+/year) — Dedicated support
   - Custom policy development
   - SIEM integration
   - 24/7 incident response
   - SLA guarantees
   - Custom supply chain policies

---

## Competitive Positioning

### vs. Cloud Sandboxes (Firecracker, Modal)

| Dimension | Cloud Sandboxes | Uncaged |
|-----------|-----------------|---------|
| Recovery time | N/A (discard instance) | <10 seconds |
| State persistence | None | Full local state |
| Latency | 500ms-5s startup | Negligible |
| Compliance | Limited visibility | Full audit trail |
| Cost | Per-execution | One-time + operational |

### vs. Container-Based (Docker, K8s)

| Dimension | Containers | Uncaged |
|-----------|-----------|---------|
| Isolation | Process + namespace | Namespace + network + privilege |
| Auditability | Limited | Comprehensive (kernel-level) |
| Recovery | Restart container | Filesystem rollback |
| Privilege model | Binary (elevated or not) | Granular (action-based) |
| Local persistence | Yes | Yes |

### vs. Traditional Sandboxing (SELinux, AppArmor)

| Dimension | MAC/Sandboxing | Uncaged |
|-----------|----------------|---------|
| Policy complexity | High (rules-based) | Low (action-based) |
| Recovery | Policy violation = blocked | Automatic rollback |
| Auditability | Policy enforcement logs | Full transaction history |
| Agent usability | Restricted (permission errors) | High agency + reversibility |

---

## Implementation Timeline

### Phase I: Foundation (Weeks 1-4)
- Btrfs deployment validation
- nftables policy framework
- Polkit action definition library
- auditd rule tuning

### Phase II: Integration (Weeks 5-8)
- Agent runtime modification
- Transaction wrapper deployment
- Validation layer implementation
- Audit log integration with SIEM

### Phase III: Operations (Weeks 9-12)
- Live agent migration
- Rollback procedure runbooks
- Compliance reporting automation
- SLA monitoring setup

---

## Success Metrics

**Operational KPIs:**
- Rollback frequency (target: <0.5% of operations)
- MTTR (target: <10 seconds)
- Audit trail completeness (target: 100%)
- Policy violation detection (target: 100% within 5 seconds)

**Business KPIs:**
- Agent uptime (target: 99.95%)
- Incident response time (target: <30 minutes from detection)
- Compliance audit findings (target: zero critical findings)
- Cost of compliance (target: 30-40% reduction vs. manual audit)

---

## Support & SLA

**Standard Support:**
- Email response: <4 hours
- Phone support: Business hours (9-17 CET)
- MTTR commitment: <30 minutes for documented procedures
- Escalation: On-call security architect

**Premium Support (Enterprise Custom):**
- 24/7 phone + email
- MTTR commitment: <15 minutes for critical incidents
- Dedicated account manager
- Quarterly compliance review

---

## Contact & Evaluation

**To schedule a risk assessment or platform demo:**
- Website: uncaged.dev
- Email: security@uncaged.dev
- Enterprise Sales: enterprise@uncaged.dev

**Evaluation includes:**
- 1-hour architecture review
- Timeline Browser demo (live rollback + recovery)
- Custom risk assessment
- Pricing based on deployment scale

---

**Uncaged: Autonomous Agents with Reversible Consequences**

*Making high-agency systems auditable, recoverable, and compliance-friendly.*
