# Contributing to Safe Unshackled Agent

Thank you for your interest in contributing! This project is about making AI agents safer without restricting their capabilities.

## Contribution Areas

### 1. Behavioral Rules (Watchdog)
Help us expand watchdog detection for suspicious behaviors:
- Network behavior patterns
- Filesystem access patterns
- Process spawning behaviors
- Resource consumption anomalies

**File:** `scripts/openclaw-watchdog.sh`

**Example:**
```bash
# Detect suspicious syscall patterns
if grep -q "clone.*CLONE_NEWUSER" /proc/self/stat; then
    echo "ALERT: User namespace creation detected"
fi
```

### 2. Canary Trap Patterns
Add new honeypot files to detect credential theft attempts:
- API tokens (OpenAI, Anthropic, Gemini, etc.)
- Database credentials
- Git tokens
- Slack/Discord webhooks

**File:** `scripts/canary-monitor.sh`

### 3. Audit Rules
Expand auditd monitoring for additional sensitive paths:
- Custom application configs
- Additional package managers
- Container runtimes
- Language-specific secret locations

**File:** `config/openclaw.rules`

### 4. Documentation
- Framework integration guides
- Troubleshooting guides
- Security hardening tips
- Case studies

**Folder:** `docs/`

### 5. Integration Examples
Add examples for:
- LangChain agents
- LLamaIndex
- AutoGPT
- Other agent frameworks

**Folder:** `examples/`

## Development Workflow

### 1. Fork & Clone
```bash
git clone https://github.com/yourusername/safe-unshackled-agent.git
cd safe-unshackled-agent
```

### 2. Create Feature Branch
```bash
git checkout -b feature/watchdog-network-detection
```

### 3. Make Changes

**For scripts:** Test on your system first
```bash
# Test watchdog rule
./scripts/openclaw-watchdog.sh --test-rule "network_behavior"

# Test canary pattern
./scripts/canary-monitor.sh --test-pattern ".env"
```

**For docs:** Use markdown with clear examples

### 4. Commit with Clear Messages
```bash
git commit -m "feat: add network behavior watchdog detection

- Detect unusual outbound connections
- Log pattern matches to alert file
- Tests passing: 25/25"
```

### 5. Submit Pull Request

Include:
- **What:** Clear description of changes
- **Why:** Motivation/problem solved
- **How:** Technical approach
- **Tests:** How you verified it works

Example PR template:
```markdown
## Watchdog: Detect Disk Device Access

### Problem
Agents attempting raw disk access should trigger immediate kill.

### Solution
Added `/dev/sd*` pattern detection to watchdog behavior scanner.

### Testing
- Tested with `dd if=/dev/sda of=/tmp/test` (triggered correctly)
- Tested with normal disk I/O (no false positives)
- Integrated with existing alert system

### Related Issues
Fixes #42
```

## Code Guidelines

### Bash Scripts
- Use `set -e` for error handling
- Quote variables: `"$VAR"`
- Use functions for reusability
- Add comments for complex logic
- Test on both Arch and Debian

### Documentation
- Use markdown
- Include code examples
- Link to relevant sections
- Test all command examples

## Testing Your Changes

### Before submitting:

1. **Linting**
   ```bash
   shellcheck scripts/*.sh
   ```

2. **Integration test**
   ```bash
   sudo ./scripts/phase7-integration-test.sh
   ```

3. **Manual verification**
   - Start agent: `systemctl --user start openclaw`
   - Trigger your feature
   - Verify logs/alerts
   - Check no false positives

## Security Considerations

When adding detection rules:

1. **False Positives:** Test legitimate agent operations
2. **Bypass Resistance:** Don't rely on behavior alone (assume it can be evaded)
3. **Reversibility:** Changes should be logged and reversible
4. **Documentation:** Explain why rule exists and what it detects

## Design Philosophy

Remember: **"The agent can do anything. But you can see everything it did, roll back anything it broke, and it dies instantly if it touches the honeypot."**

When designing features, ask:
- Does this enhance observability?
- Does this ensure reversibility?
- Does this enable circuit breakers?
- Does it maintain full agency?

## Areas We Need Help

🔴 **High Priority:**
- Enterprise SIEM integration (alerts API)
- Kubernetes agent deployment
- Multi-agent coordination safeguards

🟡 **Medium Priority:**
- MacOS/BSD support (Btrfs → ZFS adaptation)
- Non-auditd systems (syslog-based fallback)
- Container runtime integration

🟢 **Nice to Have:**
- Visual dashboard for monitoring
- Slack/Discord alert integration
- Cost analysis tools

## Questions?

- **Issues:** GitHub Issues for bugs
- **Discussions:** GitHub Discussions for ideas
- **Email:** security@example.com for sensitive topics

## License

By contributing, you agree your work is licensed under MIT (see LICENSE file).

---

**We're building the future of safe autonomous agents. Thank you for helping! 🚀**
