#!/bin/bash
# OpenClaw Configuration Snapshot Script
# Creates Btrfs snapshots of critical agent config directories
# Run manually or via systemd timer at 7:00 AM daily

set -e

SNAPSHOT_DIR="/home/.snapshots"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$HOME/.mcp-memory/snapshot-openclaw.log"

log() {
    echo "[$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$HOME/.mcp-memory"

log "=== OpenClaw Config Snapshot Started ==="

# Function to create snapshot
snapshot_dir() {
    local src="$1"
    local name="$2"

    if [ ! -d "$src" ]; then
        log "WARNING: Source directory not found: $src"
        return 1
    fi

    # Create backup directory
    local backup_dir="$SNAPSHOT_DIR/${name}-${TIMESTAMP}"
    mkdir -p "$backup_dir"

    # Use rsync for efficient backup (alternative to btrfs send/receive for user dirs)
    rsync -a --delete "$src/" "$backup_dir/" 2>/dev/null || true

    log "✓ Snapshot created: $backup_dir"
}

# Snapshot critical directories
snapshot_dir "$HOME/.openclaw" "openclaw"
snapshot_dir "$HOME/.claude" "claude"
snapshot_dir "$HOME/.mcp-memory" "mcp-memory"

# Cleanup old snapshots (keep last 10)
cleanup_snapshots() {
    local name="$1"
    local pattern="${name}-[0-9]*"
    local count=$(ls -d "$SNAPSHOT_DIR/$pattern" 2>/dev/null | wc -l)

    if [ "$count" -gt 10 ]; then
        local to_delete=$((count - 10))
        ls -dt "$SNAPSHOT_DIR/$pattern" | tail -n "$to_delete" | xargs rm -rf
        log "✓ Cleaned up $to_delete old snapshots (kept 10)"
    fi
}

cleanup_snapshots "openclaw"
cleanup_snapshots "claude"
cleanup_snapshots "mcp-memory"

log "=== OpenClaw Config Snapshot Complete ==="
log "Total snapshots: $(ls -d "$SNAPSHOT_DIR"/* 2>/dev/null | wc -l)"
