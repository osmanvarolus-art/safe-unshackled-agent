#!/bin/bash
# OpenClaw Behavioral Watchdog
# Monitors for suspicious behavior and kills agent if red lines crossed
# Run as systemd service (will be installed)

set -e

LOG_FILE="$HOME/.mcp-memory/oc-watchdog.log"
ALERT_FILE="$HOME/.mcp-memory/oc-watchdog-alert.md"

mkdir -p "$HOME/.mcp-memory"

log() {
    echo "[$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

trigger_alert() {
    local reason="$1"
    local action="$2"

    cat > "$ALERT_FILE" << EOF
# WATCHDOG ALERT — $(date -Iseconds)

**Reason:** $reason
**Action:** $action

**Next Steps:**
1. Review logs: \`journalctl --user -u openclaw --since "1 hour ago"\`
2. Check what triggered the alert
3. Investigate if this was intentional or a bug
4. Restart OpenClaw if false positive: \`systemctl --user start openclaw\`

**Previous alert time:** $(cat "$ALERT_FILE" 2>/dev/null | grep "ALERT —" | head -1)
EOF

    log "ALERT TRIGGERED: $reason"
    log "ACTION: $action"
}

check_suspicious_behavior() {
    # Get OpenClaw gateway PID from systemd
    local GWPID=$(systemctl --user show openclaw --property=MainPID --value 2>/dev/null)

    if [ -z "$GWPID" ] || [ "$GWPID" = "0" ]; then
        # Service not running, normal
        return 0
    fi

    # Check 1: Memory usage > 3.5GB (approaching 4GB limit)
    local MEM=$(systemctl --user show openclaw --property=MemoryCurrent --value 2>/dev/null)
    if [ -n "$MEM" ] && [ "$MEM" -gt 3758096384 ]; then
        log "WARNING: Memory approaching limit: $((MEM / 1024 / 1024 / 1024))GB"
        # Don't kill yet, just warn (MemoryMax will enforce)
    fi

    # Check 2: CPU usage anomaly (systemd cgroup metrics)
    local CPU=$(systemctl --user show openclaw --property=CPUUsageNSec --value 2>/dev/null)
    # Note: CPU usage tracking is complex, we rely on CPUQuota for enforcement

    # Check 3: Suspicious process children
    # Count child processes — if suddenly very high, might be fork bomb
    local CHILDREN=$(pgrep -P $GWPID 2>/dev/null | wc -l)
    if [ "$CHILDREN" -gt 50 ]; then
        trigger_alert "Excessive child processes: $CHILDREN" "Killing OpenClaw"
        systemctl --user stop openclaw
        return 1
    fi

    # Check 4: Check for suspicious file descriptor access patterns
    # (This is hard to do without inotify, we handle in canary trap instead)

    return 0
}

log "Watchdog started (PID: $$)"

while true; do
    if ! check_suspicious_behavior; then
        # trigger_alert was called inside check_suspicious_behavior
        sleep 60
        continue
    fi

    sleep 30
done
