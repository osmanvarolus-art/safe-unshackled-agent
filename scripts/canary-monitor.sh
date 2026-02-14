#!/bin/bash
# Canary Trap Honeypot Monitor
# Detects if agent attempts unauthorized access to fake secrets
# Immediate termination on any access (zero tolerance)
# Run as systemd service

set -e

LOG_FILE="$HOME/.mcp-memory/oc-canary.log"
ALERT_FILE="$HOME/.mcp-memory/oc-canary-alert.md"
CANARY_DIR="$HOME/.secrets-canary"

mkdir -p "$HOME/.mcp-memory"

log() {
    echo "[$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

log "Canary monitor started (PID: $$)"

# Check if inotify-tools is installed
if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotify-tools not installed. Install with: sudo pacman -S inotify-tools"
    log "Exiting without monitoring"
    exit 1
fi

# Check if canary directory exists
if [ ! -d "$CANARY_DIR" ]; then
    log "ERROR: Canary directory not found: $CANARY_DIR"
    log "Run: mkdir -p $CANARY_DIR"
    exit 1
fi

log "✓ inotify-tools available"
log "✓ Canary directory ready: $CANARY_DIR"
log "Monitoring for unauthorized access..."

# Start inotifywait and process events
inotifywait -m -r -e access,open "$CANARY_DIR" 2>/dev/null | while read dir event file; do
    TIMESTAMP=$(date -Iseconds)

    # Log the event
    log "CANARY TRIGGERED!"
    log "  Event: $event"
    log "  File: $dir$file"
    log "  Killing OpenClaw immediately"

    # Create alert file
    cat > "$ALERT_FILE" << EOF
# CANARY ALERT — $TIMESTAMP

⚠️ **UNAUTHORIZED ACCESS TO HONEYPOT FILE**

**Event Type:** $event
**File Accessed:** $dir$file
**Timestamp:** $TIMESTAMP
**Action Taken:** OpenClaw process killed immediately

## Investigation Steps

1. **Review OpenClaw logs:**
   \`\`\`bash
   journalctl --user -u openclaw --since "1 hour ago" -n 50
   \`\`\`

2. **Check recent commands:**
   \`\`\`bash
   history | tail -20
   \`\`\`

3. **Investigate the cause:**
   - Was this intentional? (reading fake secrets for testing?)
   - Is this a bug in OpenClaw code?
   - Check what triggered the file access

4. **If false positive, restart:**
   \`\`\`bash
   systemctl --user start openclaw
   \`\`\`

5. **Review canary logs:**
   \`\`\`bash
   cat ~/.mcp-memory/oc-canary.log
   \`\`\`

## About This Alert

This alert means the agent attempted to access files in \`~/.secrets-canary/\`:
- \`~/.secrets-canary/.env\` - Fake AWS credentials
- \`~/.secrets-canary/id_rsa\` - Fake SSH key
- \`~/.secrets-canary/passwords.txt\` - Fake passwords

These files contain no real secrets and should **never** be accessed.
Any access indicates either:
1. A bug in the agent (attempting to read unauthorized files)
2. Intentional testing of security measures
3. Malicious behavior

This is a zero-tolerance alarm.
EOF

    log "✓ Alert written to: $ALERT_FILE"

    # Kill OpenClaw
    systemctl --user stop openclaw 2>/dev/null || true

    log "✓ OpenClaw stopped"

    # Optional: Send Telegram alert if configured
    # (requires TELEGRAM_BOT_TOKEN env var)
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=🚨 CANARY ALERT: Unauthorized access to ~/.secrets-canary/$file" \
            2>/dev/null || true
    fi

    # Continue monitoring for more attempts
    log "Continuing to monitor..."
done
