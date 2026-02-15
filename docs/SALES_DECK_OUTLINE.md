# Sales Deck Outline: Transactional Execution for Autonomous Agents

**Purpose:** Close €3K+ deals with 5-minute pitch + 10-minute live demo
**Format:** PowerPoint + Terminal Demo
**Audience:** CTO, engineering leads, security leads

---

## Deck Structure (15 slides, 5 min)

### Slide 1: Title Slide
**"Give Agents a Padded Cell"**
- Tagline: Transactional Rollbacks for High-Agency Systems
- Hero copy: "Not a cage. Not a sandbox. A padded cell—they can't do permanent damage."
- Uncaged logo
- Contact info

### Slide 2: The Problem (30 seconds)
**"Agency vs. Safety"**
- Fact: LLM agents need system access to be useful
- Tension: High agency = dangerous; restricted = useless
- Question: "How do we keep agents effective without breaking production?"
- Image: Split screen (restricted sandbox vs. unrestricted agent)

### Slide 3: The Insight (30 seconds)
**"Reversibility Beats Restriction"**
- Key idea: Stop trying to prevent bad actions
- Instead: Make consequences reversible
- Example: "It's like giving agents root access inside a Git branch you can discard"
- Image: Database transaction cycle → OS operations

### Slide 4: How It Works (1 minute)
**"Transactional Rollbacks: Like PostgreSQL, But for Your OS"**
- Snapshot → Execute → Validate → Commit/Rollback (just like database transactions)
- Diagram showing 4 phases with database transaction analogy
- Example: Typosquatted package install (numpyy instead of numpy)
  1. Checkpoint taken (filesystem snapshot)
  2. Package runs, tries to exfil credentials to evil.com
  3. Network access blocked (nftables) + validation fails
  4. Rollback triggered → all changes discarded, filesystem reset
- Result: "Malware never persists. Recovery in <10 seconds vs. 4-8 hours manual."

### Slide 5: The Stack (45 seconds)
**"Four Pillars of Reversibility"**
- Pillar 1: Btrfs snapshots (Time Machine)
- Pillar 2: systemd namespaces (Local isolation)
- Pillar 3: nftables (Egress control)
- Pillar 4: Polkit (Scoped privileges)
- Visual: 4 icons showing each layer
- Callout: "All kernel-native, no containers"

### Slide 6: Why Not [Competitor] (1 minute)
**"Competitive Comparison"**

Table format:
| Dimension | Firecracker | Docker | Uncaged |
|-----------|-----------|--------|---------|
| Recovery time | N/A | Restart (60s) | <10 seconds |
| State persistence | None | Yes | Yes |
| Audit trail | Limited | Limited | Comprehensive |
| Setup complexity | High | Medium | Low |

- Key message: "Reversibility + audit + local state = unique"

### Slide 7: The Proof (1 minute)
**"Timeline Browser Demo" (LIVE)**
- "Rather than talk about it, let me show you"
- Open Timeline Browser on their system
- Show snapshots, details, comparison
- Restore a snapshot (watch it happen)
- Verify service comes back online
- Show audit trail of what happened
- Key message: "This is proof that reversibility works"

### Slide 8: Use Case: Supply Chain Attack (Supply Chain Audit Upsell) (45 seconds)
**"Protect Against Typosquatted Package Attacks"**
- Problem: LLMs hallucinate package names (numpyy, reuqests, sckit-learn)
- Risk: Adversaries register domains and distribute malware
- Traditional: Manual review + permission errors = slow
- Uncaged: Transactional rollback = attack contained automatically
- Our solution: **Supply Chain Audit** (€2.5K + €199/month)
  - Deep audit of dependencies (npm, PyPI, GitHub)
  - Rollback simulation against known attack vectors
  - Ongoing monitoring + risk reporting
- Benefit: "Agents can pull dependencies safely—with automatic protection"

### Slide 9: Compliance Alignment (45 seconds)
**"Built for Compliance"**
- SOC 2 Type II: ✅ Audit trail + automated rollback
- ISO 27001: ✅ Access control + change management
- HIPAA: ✅ Comprehensive logging + integrity controls
- PCI DSS: ✅ Cardholder data protected + full audit trail
- Message: "Recovery is your compliance story"

### Slide 10: What Gets Measured (45 seconds)
**"Operational KPIs"**
- Rollback frequency (stability signal)
- MTTR (recovery time; target <10 seconds)
- Audit trail completeness (target 100%)
- Policy violation detection (instant alerts)
- Message: "We give you metrics to prove safety"

### Slide 11: The Offer (1 minute)
**"Four Ways to Get Started"**

1. **Quick Risk Scan** (€490, 1 day)
   - Architecture review + Timeline Browser demo
   - Risk assessment + recommendations
   - → Qualify for sprint or audit

2. **Supply Chain Audit** (€2,500 + €199/month, optional)
   - Deep audit of all agent dependencies
   - Rollback simulation testing
   - Ongoing supply chain monitoring
   - → Essential if using npm/PyPI agents

3. **Hardened Sprint** (€3,000, 5 days)
   - Deploy full Uncaged stack
   - Timeline Browser becomes your operational tool
   - → 90% convert to Runtime Care

4. **Runtime Care** (€39/month or €199/month with audit, ongoing)
   - Continuous monitoring + audit reporting
   - Policy updates + incident response
   - Supply chain monitoring (€199/month tier)

### Slide 12: Revenue Impact (45 seconds)
**"Cost of the Alternative"**
- Manual recovery from agent failure: 4-8 hours
- Average cost per incident: €2,000-5,000
- Compliance audit costs: €50K+/year
- Uncaged cost: €3,000 sprint + €39/month
- Break-even: 1-2 incidents
- Message: "Pays for itself on first incident"

### Slide 13: Customer Story (30 seconds, optional)
**"Real Example: [Customer Name]"**
- Before: "Agent failures = 4-hour manual recovery"
- After: "Agent failures = 10-second automatic recovery"
- Results: 98% MTTR improvement, 0 compliance findings
- Quote: "[CTO]: 'Now our agents can move fast—we have the undo button'"

### Slide 14: Next Steps (30 seconds)
**"Let's Start with a Risk Scan"**
- Option 1: Schedule 1-day assessment (€490)
  - We review your architecture
  - Demo Timeline Browser
  - Provide risk report + recommendations
- Option 2: Skip to sprint (€3,000, 5 days)
  - Full deployment + your team trained
  - Timeline Browser becomes your operational tool
- Question: "Which timeline works for you?"

### Slide 15: Close Slide
**"The Undo Button for Your Team"**
- Contact info
- uncaged.dev
- email: sales@uncaged.dev
- CTA: "Let's schedule a risk assessment"

---

## Demo Script (10 minutes)

### Setup (before call)
```bash
# Ensure system has active snapshots
ls /home/.snapshots/openclaw-*

# Have timeline-browser.sh ready
cd ~/Projects/safe-unshackled-agent/scripts/
```

### Demo Flow

#### Part 1: Browse Snapshots (2 min)
```bash
./timeline-browser.sh

# Show main menu: list of snapshots with event counts
# Navigate with arrow keys, show 2-3 snapshots

# Explain:
"These are snapshots of our agent's configuration at different points in time.
Each one shows the number of events that happened around that snapshot.
It's like 'git log' for your entire system."
```

**Key talking points:**
- Event counts show activity level
- Older snapshots = known-good states
- Ability to see history is the first step to reversibility

#### Part 2: View Snapshot Details (2 min)
```
Select a snapshot → Press Enter
Show: size, file count, recent events

# Explain:
"This tells us what was happening around this snapshot.
We can see watchdog alerts, git commits, honeypot access attempts, all in timeline.
This is our audit trail—everything's visible."
```

**Key talking points:**
- Full visibility into what changed
- Events from 5 different sources correlated
- This is what your compliance team wants to see

#### Part 3: Compare Snapshots (2 min)
```
Press 'd' for diff
Select two snapshots (older, then newer)
Show: file changes (added/removed/modified)

# Explain:
"Now we can see exactly what changed between snapshots.
Green = files added, red = files removed, yellow = files modified.
We can also see JSON diffs for your configuration files."
```

**Key talking points:**
- Instant visibility into "what changed"
- Useful for debugging ("Did the config get corrupted?")
- JSON-aware so we can see config value changes

#### Part 4: Restore with Rollback (3 min)
```
Press 'r' for restore
Select a snapshot to restore
Confirm: [y]

# Watch:
- Emergency backup created
- Files restored
- Service verification happening
- Status messages showing progress

# Explain as it happens:
"Watch what's happening:
1. We created an emergency backup of the current state
2. We stopped the service
3. We're restoring files from the snapshot
4. We're restarting the service
5. We're verifying the service is running...

If anything fails, we automatically rollback.
Recovery time: <10 seconds."

# Once complete:
"And we're done. The service is running again.
Your emergency backup is preserved at [path] if you want to review it."
```

**Key talking points:**
- Safety: emergency backup before any changes
- Automation: no manual commands needed
- Speed: <10 seconds total
- Auditability: every step logged

#### Part 5: Audit Trail (1 min)
```
Show event timeline during restore
Show audit log entries

# Explain:
"This is your complete audit trail.
Every operation is logged: timestamp, who did it, what changed, result.
This is what your compliance team needs for SOC 2, ISO 27001, HIPAA audits."
```

**Key talking points:**
- Immutable audit trail
- Full context (who, what, when, why)
- Automated compliance evidence

---

## Conversation Templates

### Opening Question
> "Can I show you something? Rather than talk about it, let me demonstrate transactional execution on your actual system. I'll restore a snapshot—watch what happens and how fast."

### After Demo: Closing Question
> "You see how reversibility works? That's the core of Uncaged. So here's what we're proposing: let's start with a one-day risk assessment (€490) where we review your architecture and show your team Timeline Browser in action. If you like what you see, we move to a five-day sprint (€3K) where we deploy the full stack. Does that make sense?"

### Handling Objections

**"Our current approach works fine"**
> "That's good. What happens when an agent mistake breaks production? How long does recovery take? [Wait for answer] Our customers went from [their time] to <10 seconds. Let me show you how that's possible."

**"We use containers (Docker/K8s)"**
> "Containers are great for isolation. But they don't solve the recovery problem—if an agent corrupts something, you still have to debug, fix, and restart. We make recovery automatic. Watch this demo."

**"This sounds complicated"**
> "It's actually simpler than it sounds. Timeline Browser is the only interface your team needs. You browse snapshots, compare if needed, and restore if something breaks. We handle all the complexity underneath."

**"How much does it cost?"**
> "We have three options. First: €490 risk assessment—one day, we review your setup and show Timeline Browser. Second: €3K sprint—five days, full deployment. Third: €39/month ongoing—monitoring, updates, compliance reporting. Most customers start with the assessment to make sure we're a fit."

**"We need to check with [other team]"**
> "Totally. Let me email you the one-pager and the HackerNews post we published. Show your security team the demo video. And let's schedule a follow-up call with whoever else needs to see this. When works?"

---

## Follow-Up Email Template

**Subject:** "Uncaged Demo: Timeline Browser + Transactional Execution"

```
Hi [Name],

Thanks for the call today. As promised, here are the materials:

1. ENGINEERING PERSPECTIVE: [Link to SYNTHESE_HN.md]
   Credible, technical deep-dive on why reversibility beats restriction

2. ENTERPRISE PERSPECTIVE: [Link to SYNTHESE_ENTERPRISE.md]
   Compliance focus (SOC 2, ISO 27001, HIPAA alignment)

3. STRATEGIC OVERVIEW: [Link to STRATEGIC_POSITIONING_REPORT.md]
   Revenue model + how this fits into your infrastructure

4. DEMO VIDEO: [Link to 30-second Timeline Browser restore demo]
   Show your team in 30 seconds how fast recovery is

5. USER GUIDE: [Link to TIMELINE_BROWSER.md]
   Full documentation if your team wants technical details

Next steps:
- Share with your security team
- If interested, let's schedule a one-day risk assessment (€490)
- We'll review your architecture and give you a real demo on your system

Feel free to reach out with questions.

Best,
[Your name]
```

---

## Closing Checklist

Before each call:
- [ ] Timeline Browser working on your laptop
- [ ] Test live demo (snapshots exist, restore works)
- [ ] Have demo video backup (in case tech fails)
- [ ] Slides loaded and tested
- [ ] Follow-up email template ready
- [ ] Next-steps options clear (€490 scan vs €3K sprint)

During call:
- [ ] Establish problem (agency vs. safety)
- [ ] Show insight (reversibility beats restriction)
- [ ] Run live demo (5 min Timeline Browser)
- [ ] Show competitor comparison
- [ ] Explain offer (€490 → €3K → €39/month)
- [ ] Advance to next step (calendar invite for assessment)

After call:
- [ ] Send follow-up email within 1 hour
- [ ] Share materials (synthèse + demo video)
- [ ] Schedule follow-up call
- [ ] Mark in CRM with next action

---

## Success Metrics

**For this sales deck:**
- [ ] 80%+ of prospects watch full 10-minute demo
- [ ] 70%+ of prospects show interest in next step (€490 assessment)
- [ ] 50%+ close from assessment to sprint (€3K)
- [ ] 90%+ of sprint customers move to Runtime Care (€39/month)

**For your conversation:**
- [ ] Demo runs without technical issues
- [ ] You articulate 3 reasons reversibility beats restriction
- [ ] Prospect asks "how do we get started?" (you won)
- [ ] Follow-up email sent within 1 hour

---

**Remember:** The demo is the star. The deck is just context. Let Timeline Browser do the selling.
