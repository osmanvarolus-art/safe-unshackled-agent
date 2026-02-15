# Timeline Browser User Guide

**OpenClaw Timeline Browser — "Git Time Machine for your entire system"**

A terminal-based snapshot management interface for browsing, comparing, and safely restoring your OpenClaw agent configuration.

> **Part of the Uncaged Platform:** Timeline Browser demonstrates transactional execution—the core mechanism for making autonomous agents safe by making consequences reversible instead of trying to prevent all bad actions. See [SYNTHESE_HN.md](SYNTHESE_HN.md) or [STRATEGIC_POSITIONING_REPORT.md](STRATEGIC_POSITIONING_REPORT.md) for the broader vision.

---

## Quick Start

### Launch Timeline Browser

```bash
~/Projects/safe-unshackled-agent/scripts/timeline-browser.sh
```

### Main Menu

```
OpenClaw Timeline Browser

Select snapshot or action:
  [1] openclaw-20260215-100000 (12 events)
  [2] openclaw-20260214-120000 (5 events)
  [3] openclaw-20260213-070000 (8 events)

  [d] View diff between two snapshots
  [r] Restore from snapshot
  [q] Quit
```

Use arrow keys to navigate, Enter to select.

---

## Features

### 1. Browse Snapshots
List all available snapshots with:
- **Timestamp** when snapshot was created
- **Event count** showing activity around that time
- **Size** of the snapshot
- **File count** for quick assessment

### 2. View Snapshot Details
Select a snapshot to see:
- Full path and metadata
- Size in human-readable format (2.3M, 1.5G, etc.)
- Total files contained
- Recent events (snapshot creation, watchdog alerts, git commits, canary triggers)

### 3. Compare Snapshots (Diff)
Compare two snapshots side-by-side to see:
- **Added files** (green `+`) - new in newer snapshot
- **Removed files** (red `-`) - deleted in newer snapshot
- **Modified files** (yellow `M`) - changed between snapshots
- **JSON changes** - for configuration files

Useful for:
- "What changed between snapshots?"
- "Did the config get corrupted?"
- "When did file X get added?"

### 4. Restore from Snapshot
One-click restore with automatic safety:
1. **User confirmation** - requires explicit `[y/N]` confirmation
2. **Emergency backup** - current config backed up before restore
3. **Service control** - OpenClaw stopped before file operations
4. **Atomic restore** - files copied from snapshot
5. **Service restart** - OpenClaw automatically restarted
6. **Verification** - confirms service is running
7. **Auto-rollback** - if verification fails, automatic rollback to emergency backup

---

## Usage Scenarios

### Scenario 1: Debug Configuration Change

**Problem:** OpenClaw configuration was modified and now the service won't start.

**Solution:**
1. Launch `timeline-browser.sh`
2. Browse snapshots to find one from **before** the change
3. Select snapshot → view details to confirm it's the right one
4. Press `d` for diff, compare with current snapshot
5. See what changed in `openclaw.json`
6. Press `r` to restore
7. Confirm restore with `[y]`
8. Watch as emergency backup is created, files are restored, service restarts
9. Verify success message ✓ with running service

**Result:** OpenClaw working again, configuration reverted, emergency backup kept for reference.

### Scenario 2: Investigate Watchdog Alert

**Problem:** Watchdog triggered an alert about suspicious activity.

**Solution:**
1. Launch `timeline-browser.sh`
2. Find snapshot **around the time** of the alert
3. View snapshot details → see "Recent Events"
4. Look for `[WATCHDOG]` events in the timeline
5. Compare snapshots before/after the alert with diff
6. Check file changes to understand what triggered the alert
7. Restore if the alert indicates compromise

**Result:** Full visibility into what was happening at the time of the alert.

### Scenario 3: Clean Up After Failed Experiment

**Problem:** Modified configuration to test something new, but want to revert.

**Solution:**
1. Launch `timeline-browser.sh`
2. Find snapshot from **before** the experiment
3. Press `r` to restore
4. Confirm restore
5. Done — system back to known-good state

**Result:** One command to undo all changes.

### Scenario 4: Compare Two Specific Snapshots

**Problem:** Want to see what changed over the last week.

**Solution:**
1. Launch `timeline-browser.sh`
2. Press `d` for diff menu
3. Select snapshot from 1 week ago (older snapshot)
4. Select today's snapshot (newer snapshot)
5. View full diff in terminal
6. Use arrow keys to scroll, `q` to return to menu

**Result:** Complete change history showing all file modifications.

---

## Menu Navigation

### Main Menu
```
Arrow Keys    Navigate snapshot list
Enter         Select snapshot (view details)
d             Open Diff Menu
r             Open Restore Menu
q             Quit Timeline Browser
```

### Snapshot Details View
```
Displays: snapshot path, size, file count, recent events
Press: [Enter] to return to main menu
```

### Diff Menu
```
Select first snapshot (older), then second (newer)
View diff with colors:
  GREEN  + Added files
  RED    - Removed files
  YELLOW M Modified files
  BLUE   (headers, JSON changes)
Press: q to return to main menu
```

### Restore Menu
```
Select snapshot to restore
WARNING: This will overwrite current config!
Confirmation: [y/N] - type 'y' to proceed
Watch restore progress with status messages
Press: [Enter] after completion to return to main menu
```

---

## Safety Guarantees

### Before Every Restore

✅ **User Confirmation Required**
- Always prompts before any destructive action
- Shows snapshot name and target directory
- Requires explicit `y` to proceed

✅ **Emergency Backup Created**
- Automatic snapshot of current config taken before restore
- Named: `openclaw-emergency-YYYYMMDD-HHMMSS`
- Saved to `/home/.snapshots/` (same location as regular snapshots)
- **Never automatically deleted** (preserved for manual cleanup)

✅ **Service Stopped**
- OpenClaw service stopped before file operations
- Ensures no locks or file conflicts

✅ **Atomic File Restoration**
- All files restored from selected snapshot
- Target directory cleared first
- Files copied cleanly

✅ **Service Restarted**
- OpenClaw automatically restarted after restore
- Service allowed 3-5 seconds to initialize

### After Every Restore

✅ **Automatic Verification**
- Confirms OpenClaw service is running
- If running: restore declared SUCCESS ✓
- If NOT running: automatic rollback triggered

✅ **Automatic Rollback on Failure**
- If OpenClaw fails to start after restore:
  1. Notification displayed: "RESTORE FAILED - AUTOMATIC ROLLBACK SUCCEEDED"
  2. Emergency backup files restored
  3. OpenClaw service restarted
  4. System returned to state before attempted restore
  5. User prompted to check logs

### Rollback Details

If restoration fails and rollback is triggered:

1. **Emergency backup restored**
   - Files from emergency backup copied back to `~/.openclaw/`

2. **Service restarted**
   - OpenClaw restarted with emergency backup config

3. **Verification repeated**
   - Confirms service is running after rollback

4. **Status reported**
   - User sees clear message about rollback success
   - Logs show what happened

5. **Emergency backup preserved**
   - Emergency backup **not** deleted
   - Manual cleanup: `rm -rf /home/.snapshots/openclaw-emergency-*`

### Manual Recovery (Worst Case)

If everything fails:

1. **Location of emergency backup shown**
2. **Manual commands provided:**
   ```bash
   rm -rf ~/.openclaw/*
   cp -a /home/.snapshots/openclaw-emergency-YYYYMMDD-HHMMSS/* ~/.openclaw/
   systemctl --user start openclaw
   ```
3. **Log information provided:**
   ```bash
   journalctl --user -u openclaw -n 50
   tail -50 ~/.mcp-memory/snapshot-openclaw.log
   ```

---

## Log Files

### Snapshot Operations Log
```
~/.mcp-memory/snapshot-openclaw.log
```

Records:
- When snapshots are created
- When restores are initiated
- When rollbacks occur
- All restore operations and their outcomes

Example:
```
[2026-02-15T10:30:00+01:00] SNAPSHOT: Snapshot created: /home/.snapshots/openclaw-20260215-103000
[2026-02-15T10:35:00+01:00] RESTORE: Initiated restore from openclaw-20260215-103000
[2026-02-15T10:35:01+01:00] RESTORE: Emergency backup created: /home/.snapshots/openclaw-emergency-20260215-103501
[2026-02-15T10:35:02+01:00] RESTORE: Service stopped
[2026-02-15T10:35:03+01:00] RESTORE: Files restored
[2026-02-15T10:35:05+01:00] RESTORE: Service restarted
[2026-02-15T10:35:08+01:00] RESTORE: SUCCESS: Restore completed and verified
```

### Service Logs
```bash
journalctl --user -u openclaw -n 50      # Recent OpenClaw logs
journalctl --user -u openclaw -f         # Follow logs in real-time
journalctl --user -u openclaw --since 1h # Last hour
```

### Event Timeline
Timeline Browser correlates events from:
1. **Snapshot log** - when snapshots were created
2. **Watchdog log** - behavioral alerts and warnings
3. **Canary log** - honeypot access attempts
4. **Git history** - configuration commits
5. **Journald** - service start/stop/restart events

---

## Troubleshooting

### "No snapshots found"
**Cause:** `/home/.snapshots/` directory is empty or doesn't exist
**Solution:**
- Snapshots are created by `snapshot-openclaw.sh` (usually via cron)
- Run manually: `~/.local/bin/snapshot-openclaw` (if it exists)
- Or wait for next scheduled snapshot

### "Restore failed - rollback succeeded"
**Cause:** Selected snapshot has corrupted config that prevents OpenClaw startup
**Solution:**
1. Emergency backup preserved at shown path
2. Check logs: `journalctl --user -u openclaw -n 50`
3. Select a different, older snapshot to restore
4. Or manually examine emergency backup: `ls /home/.snapshots/openclaw-emergency-*/`

### "Service verification failed"
**Cause:** OpenClaw taking longer than expected to start
**Solution:**
- Rollback triggered automatically ✓
- System restored to pre-restore state
- Check: `journalctl --user -u openclaw`
- Wait 10 seconds and manually check: `systemctl --user status openclaw`

### "Permission denied" errors
**Cause:** Insufficient permissions to read snapshot directory or restore files
**Solution:**
- Timeline Browser should run as your user (no sudo needed)
- Check snapshot permissions: `ls -la /home/.snapshots/`
- All operations use user-level systemctl (not system-wide)

### "Diff shows no changes"
**Cause:** Both snapshots are identical
**Solution:**
- This is correct behavior (they truly are identical)
- Compare with a different snapshot
- Or check file timestamps: `stat /path/to/file`

### "Whiptail menu not responding"
**Cause:** Terminal doesn't support whiptail (rare)
**Solution:**
- Ensure you have: `which whiptail`
- Check Arch package: `pacman -S newt`
- Try in different terminal (konsole, xterm, gnome-terminal)

---

## Performance Notes

### Speed Characteristics
| Operation | Time |
|-----------|------|
| Discover snapshots | <100ms |
| Show snapshot details | <200ms |
| Compute diff (1 week) | 1-3 sec |
| Restore operation | 5-10 sec |
| Rollback operation | 5-10 sec |

### Scalability Limits
- **100+ snapshots:** Still fast (<1 second discovery)
- **7-day archive:** Typical use case, optimal performance
- **1GB+ snapshots:** Diff may take 10+ seconds, but system handles gracefully

### Resource Usage
- **Memory:** <20MB typical
- **CPU:** Minimal (mostly disk I/O)
- **Disk:** Temporary space for emergency backup (size = current config size)

---

## Integration with OpenClaw Resilience Stack

Timeline Browser fits into the 9-layer resilience architecture:

1. **Btrfs Snapshots** ← Timeline Browser manages interactive access
2. **Git Config** ← Integrated into timeline view
3. **Immutable Files** ← Protected files shown in diffs but read-only
4. **Scoped Sudo Bridge** ← No escalation needed (user-level operations)
5. **Resource Limits** ← Restore respects cgroup limits
6. **Auditd** ← Restore operations logged
7. **Watchdog** ← Can correlate with timeline view
8. **Canary Trap** ← Honeypot access shown in timeline
9. **Nftables** ← Restore preserves network isolation

---

## Advanced Usage

### Command-Line Library Functions

Timeline Browser is built on reusable Bash libraries. Advanced users can use them directly:

```bash
# Load libraries
source ~/Projects/safe-unshackled-agent/lib/snapshot-parser.sh
source ~/Projects/safe-unshackled-agent/lib/event-correlator.sh
source ~/Projects/safe-unshackled-agent/lib/diff-engine.sh
source ~/Projects/safe-unshackled-agent/lib/restore-manager.sh

# List snapshots
list_snapshots | head -5

# Count events in time range
count_events_between "2026-02-14T00:00:00+01:00" "2026-02-15T00:00:00+01:00"

# Diff two snapshots
diff_snapshots /home/.snapshots/openclaw-20260214-* /home/.snapshots/openclaw-20260215-*

# Get largest changes
get_largest_changes /home/.snapshots/openclaw-20260214-* /home/.snapshots/openclaw-20260215-*
```

### Scripting Restore Operations

For automated restoration:

```bash
#!/bin/bash
source ~/Projects/safe-unshackled-agent/lib/restore-manager.sh

# Restore with programmatic control
restore_snapshot "/home/.snapshots/openclaw-20260215-000005"

# Check result
if [ $? -eq 0 ]; then
    echo "Restore successful"
else
    echo "Restore failed - check logs"
fi
```

### Automation Ideas

1. **Daily backup to external storage**
   ```bash
   rsync -av /home/.snapshots/openclaw-* /mnt/backup/
   ```

2. **Cleanup old snapshots**
   ```bash
   ls -t /home/.snapshots/openclaw-[0-9]* | tail -n +11 | xargs rm -rf
   ```

3. **Restore on startup failure**
   ```bash
   # If OpenClaw fails to start, restore previous snapshot
   systemctl --user start openclaw || restore_snapshot $(list_snapshots | head -2)
   ```

---

## FAQ

**Q: Do I lose my current configuration when I restore?**
A: No. An emergency backup is created first. Your current config is preserved at `/home/.snapshots/openclaw-emergency-YYYYMMDD-HHMMSS` for manual review.

**Q: Can I restore to a snapshot from 6 months ago?**
A: Only if the snapshot still exists. Timeline Browser keeps the last 10 snapshots (typically ~10 days of history). Older snapshots are automatically cleaned up by retention policy.

**Q: What if I restore but then realize I needed the new config?**
A: Your "new" config is preserved in the emergency backup (created before restore). You can restore from that emergency backup manually, or look at the diffs to see what changed.

**Q: Do I need to stop OpenClaw manually before restoring?**
A: No. Timeline Browser automatically stops the service before restore and restarts it afterward. No manual intervention needed.

**Q: What happens if I disconnect power during restore?**
A: Unsafe. Timeline Browser uses file operations (not Btrfs snapshot swap), so partial restore is possible. After power restore, manually check: `systemctl --user status openclaw` and review emergency backup if needed.

**Q: Can multiple people use Timeline Browser simultaneously?**
A: Not safely. If two users try to restore at the same time, they may conflict. Use user-level systemd (each user has their own OpenClaw), so conflicts are unlikely but theoretically possible.

**Q: How big are the snapshots?**
A: Typically 1-5MB for a full OpenClaw config. Snapshots are incremental (rsync copies), not full disk images. Emergency backups are the same size.

**Q: Can I automate snapshot creation?**
A: Yes. Snapshots are created by `snapshot-openclaw.sh` via cron. Check: `crontab -l` or systemd timers.

---

## Support & Troubleshooting

### Check System Status
```bash
# OpenClaw status
systemctl --user status openclaw

# Snapshot directory
ls -lah /home/.snapshots/

# Recent logs
journalctl --user -u openclaw -n 20
tail -20 ~/.mcp-memory/snapshot-openclaw.log

# Emergency backups
ls -lah /home/.snapshots/openclaw-emergency-*
```

### Generate Diagnostic Report
```bash
echo "=== OpenClaw Status ===" > timeline-browser-report.txt
systemctl --user status openclaw >> timeline-browser-report.txt 2>&1
echo "=== Snapshots ===" >> timeline-browser-report.txt
ls -lah /home/.snapshots/openclaw-[0-9]* >> timeline-browser-report.txt 2>&1
echo "=== Recent Logs ===" >> timeline-browser-report.txt
journalctl --user -u openclaw -n 20 >> timeline-browser-report.txt 2>&1
echo "=== Report saved to timeline-browser-report.txt ==="
```

---

## Version Info

- **Timeline Browser Version:** 1.0 (Phase 6 complete)
- **Test Status:** ✅ 41/41 tests passed
- **Required Bash Version:** 4.0+
- **Compatible Platforms:** Linux (Arch, Debian, CentOS with bash 4.0+)
- **Dependencies:** find, grep, sed, sort, cut, wc, du, stat, systemctl, whiptail, jq, git (all standard)

---

## Additional Resources

- **Project Repository:** `/home/osman/Projects/safe-unshackled-agent/`
- **Test Suite:** `/home/osman/Projects/safe-unshackled-agent/test/test-timeline-browser.sh`
- **Test Report:** `/home/osman/Projects/safe-unshackled-agent/test/TEST_REPORT.md`
- **Library Documentation:** Individual library files in `lib/`
- **Resilience Stack Docs:** `docs/RESILIENCE_STACK.md`

---

**Timeline Browser — Making System Recovery Fast, Safe, and Reversible**

Last updated: 2026-02-15
