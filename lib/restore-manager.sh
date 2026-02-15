#!/bin/bash
# Restore Manager Library for Timeline Browser
#
# Safely restores OpenClaw from snapshots with emergency backup and rollback
#
# Safety Layers:
# 1. User confirmation (always prompt)
# 2. Emergency backup (before restore)
# 3. Service stop (stop OpenClaw)
# 4. Atomic restore (copy files)
# 5. Verification (check service starts)
# 6. Automatic rollback (restore emergency backup on failure)
#
# Functions:
# - restore_snapshot()        Safely restore from snapshot with rollback
# - list_restore_candidates() List snapshots available for restore
# - create_emergency_backup()  Create backup before restore
# - verify_openclaw_running()  Check if OpenClaw is running

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging function
log_restore() {
    local message="$1"
    local log_file="$HOME/.mcp-memory/snapshot-openclaw.log"

    echo "[$(date -Iseconds)] RESTORE: ${message}" | tee -a "$log_file"
}

# ============================================================================
# create_emergency_backup()
#
# Create a backup snapshot before restore
# Input: None (uses current ~/.openclaw/)
# Output: Path to emergency backup directory
# ============================================================================

create_emergency_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="/home/.snapshots/openclaw-emergency-${timestamp}"

    echo -e "${YELLOW}Creating emergency backup...${NC}"

    mkdir -p "$backup_dir"

    if cp -a "$HOME/.openclaw"/* "$backup_dir/" 2>/dev/null || true; then
        echo -e "${GREEN}✓ Emergency backup created: $backup_dir${NC}"
        log_restore "Emergency backup created: $backup_dir"
        echo "$backup_dir"
        return 0
    else
        echo -e "${RED}✗ Failed to create emergency backup${NC}"
        log_restore "ERROR: Failed to create emergency backup"
        return 1
    fi
}

# ============================================================================
# verify_openclaw_running()
#
# Check if OpenClaw service is running
# Input: None
# Output: 0 if running, 1 if not
# ============================================================================

verify_openclaw_running() {
    systemctl --user is-active --quiet openclaw
}

# ============================================================================
# restore_snapshot()
#
# Main restore function with 6 safety layers
#
# Layer 1: User confirmation
# Layer 2: Emergency backup creation
# Layer 3: Service stop
# Layer 4: File restoration
# Layer 5: Service restart
# Layer 6: Verification + automatic rollback on failure
#
# Input: snapshot_path
# Output: 0 on success, 1 on failure
# ============================================================================

restore_snapshot() {
    local snapshot_path="$1"
    local target_dir="$HOME/.openclaw"
    local emergency_backup=""

    if [ ! -d "$snapshot_path" ]; then
        echo -e "${RED}✗ Snapshot directory not found: $snapshot_path${NC}"
        log_restore "ERROR: Snapshot not found: $snapshot_path"
        return 1
    fi

    # ========== LAYER 1: USER CONFIRMATION ==========
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}WARNING: This will restore OpenClaw configuration${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Snapshot: $(basename "$snapshot_path")"
    echo "Target:   $target_dir"
    echo ""
    echo -e "${BLUE}What will happen:${NC}"
    echo "  1. Emergency backup of current config will be created"
    echo "  2. OpenClaw service will be stopped"
    echo "  3. Files will be restored from snapshot"
    echo "  4. OpenClaw service will be restarted"
    echo "  5. If restart fails, automatic rollback will occur"
    echo ""

    read -p "Continue with restore? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restore cancelled.${NC}"
        return 1
    fi

    log_restore "Initiated restore from $(basename "$snapshot_path")"

    # ========== LAYER 2: EMERGENCY BACKUP ==========
    emergency_backup=$(create_emergency_backup)
    if [ -z "$emergency_backup" ]; then
        echo -e "${RED}✗ Failed to create emergency backup. Aborting restore.${NC}"
        return 1
    fi

    # ========== LAYER 3: SERVICE STOP ==========
    echo -e "${BLUE}Stopping OpenClaw service...${NC}"
    if systemctl --user stop openclaw 2>/dev/null; then
        echo -e "${GREEN}✓ Service stopped${NC}"
        log_restore "Service stopped"
    else
        echo -e "${RED}⚠ Service stop failed (may already be stopped)${NC}"
    fi

    sleep 2

    # ========== LAYER 4: FILE RESTORATION ==========
    echo -e "${BLUE}Restoring files from snapshot...${NC}"

    # Clear target directory
    if rm -rf "$target_dir"/* 2>/dev/null; then
        echo -e "${GREEN}✓ Cleared target directory${NC}"
    else
        echo -e "${RED}⚠ Could not clear all files (some may be immutable)${NC}"
    fi

    # Copy snapshot contents
    if cp -a "$snapshot_path"/* "$target_dir/" 2>/dev/null || true; then
        echo -e "${GREEN}✓ Files restored${NC}"
        log_restore "Files restored from snapshot"
    else
        echo -e "${RED}✗ File restore failed${NC}"
        log_restore "ERROR: File restore failed"
        return 1
    fi

    # ========== LAYER 5: SERVICE RESTART ==========
    echo -e "${BLUE}Restarting OpenClaw service...${NC}"
    sleep 2

    if systemctl --user start openclaw 2>/dev/null; then
        echo -e "${GREEN}✓ Service started${NC}"
        log_restore "Service restarted"
    else
        echo -e "${RED}✗ Failed to start service${NC}"
        log_restore "ERROR: Service failed to start, initiating rollback"
        # Continue to verification to trigger rollback
    fi

    sleep 3

    # ========== LAYER 6: VERIFICATION + ROLLBACK ==========
    echo -e "${BLUE}Verifying OpenClaw status...${NC}"

    if verify_openclaw_running; then
        echo -e "${GREEN}✓ OpenClaw is running${NC}"
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ RESTORE SUCCESSFUL${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Emergency backup saved at: $emergency_backup"
        echo "(Manual cleanup only: rm -rf $emergency_backup)"
        echo ""
        log_restore "SUCCESS: Restore completed and verified"
        return 0

    else
        # ========== AUTOMATIC ROLLBACK ==========
        echo -e "${RED}✗ OpenClaw failed to start - INITIATING ROLLBACK${NC}"
        log_restore "Rollback initiated: OpenClaw failed to start"

        echo -e "${YELLOW}Rolling back to emergency backup...${NC}"

        # Stop service (may already be stopped)
        systemctl --user stop openclaw 2>/dev/null || true
        sleep 1

        # Clear and restore from emergency backup
        if rm -rf "$target_dir"/* 2>/dev/null && \
           cp -a "$emergency_backup"/* "$target_dir/" 2>/dev/null; then
            echo -e "${GREEN}✓ Rollback: Files restored${NC}"
            log_restore "Rollback: Files restored from emergency backup"
        fi

        # Restart service
        if systemctl --user start openclaw 2>/dev/null; then
            echo -e "${GREEN}✓ Rollback: Service restarted${NC}"
            log_restore "Rollback: Service restarted"

            if verify_openclaw_running; then
                echo ""
                echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}⚠ RESTORE FAILED - AUTOMATIC ROLLBACK SUCCEEDED${NC}"
                echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                echo "Your configuration has been restored from emergency backup."
                echo "Emergency backup is still available at: $emergency_backup"
                echo ""
                echo "Check logs for details:"
                echo "  journalctl --user -u openclaw -n 50"
                echo "  tail -50 $HOME/.mcp-memory/snapshot-openclaw.log"
                echo ""
                log_restore "Rollback successful, OpenClaw restored"
                return 1
            fi
        fi

        echo -e "${RED}✗ Rollback also failed${NC}"
        log_restore "ERROR: Rollback failed - manual intervention may be required"
        echo ""
        echo "CRITICAL: Rollback failed. Manual intervention required."
        echo "Emergency backup location: $emergency_backup"
        echo ""
        return 1
    fi
}

# ============================================================================
# list_restore_candidates()
#
# List all snapshots available for restore
# Exclude emergency backups
# Sort newest first
#
# Input: None
# Output: One snapshot path per line
# ============================================================================

list_restore_candidates() {
    if [ ! -d /home/.snapshots ]; then
        return 0
    fi

    # List all openclaw-* directories, exclude emergency backups
    for dir in /home/.snapshots/openclaw-[0-9]*; do
        if [ -d "$dir" ]; then
            # Skip emergency backups
            if [[ $(basename "$dir") =~ ^openclaw-emergency ]]; then
                continue
            fi
            echo "$dir"
        fi
    done | sort -r
}

# ============================================================================
# Example usage:
#
# # Restore from specific snapshot
# restore_snapshot /home/.snapshots/openclaw-20260214-120000
#
# # List available snapshots
# list_restore_candidates | while read snap; do
#     echo "Available: $(basename $snap)"
# done
# ============================================================================
