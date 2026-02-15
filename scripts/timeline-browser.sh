#!/bin/bash
# Timeline Browser — OpenClaw Snapshot Management UI
#
# Interactive terminal UI for browsing, comparing, and restoring system snapshots
# "Git Time Machine for your entire system"
#
# Features:
# - List snapshots with event counts
# - View snapshot details
# - Compare two snapshots (diffs)
# - Restore from snapshot with emergency backup
# - Automatic rollback on restore failure

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"

# Load libraries
source "$LIB_DIR/snapshot-parser.sh" 2>/dev/null || { echo "Error: snapshot-parser.sh not found"; exit 1; }
source "$LIB_DIR/event-correlator.sh" 2>/dev/null || { echo "Error: event-correlator.sh not found"; exit 1; }
source "$LIB_DIR/diff-engine.sh" 2>/dev/null || { echo "Error: diff-engine.sh not found"; exit 1; }
source "$LIB_DIR/restore-manager.sh" 2>/dev/null || { echo "Error: restore-manager.sh not found"; exit 1; }

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# main_menu()
#
# Display main snapshot browser menu
# ============================================================================

main_menu() {
    # Build snapshot list for whiptail
    local snapshots=()
    local idx=1

    while IFS='|' read -r timestamp path; do
        local basename=$(basename "$path")
        local event_count=$(count_events_between "$timestamp" "$(date -Iseconds)" 2>/dev/null || echo "?")

        snapshots+=("$idx" "$basename ($event_count events)")
        ((idx++))
    done < <(list_snapshots)

    if [ ${#snapshots[@]} -eq 0 ]; then
        whiptail --title "Timeline Browser" --msgbox "No snapshots found in /home/.snapshots/" 8 60
        return 0
    fi

    # Show main menu
    local choice=$(whiptail --title "OpenClaw Timeline Browser" \
                            --menu "Select snapshot or action:" 22 90 12 \
                            "${snapshots[@]}" \
                            "" "" \
                            "d" "View diff between two snapshots" \
                            "r" "Restore from snapshot" \
                            "q" "Quit" \
                            3>&1 1>&2 2>&3)

    case "$choice" in
        q|"") return 0 ;;
        d) diff_menu ;;
        r) restore_menu ;;
        [0-9]*)
            local snapshot_path=$(list_snapshots | sed -n "${choice}p" | cut -d'|' -f2)
            view_snapshot_details "$snapshot_path"
            ;;
    esac

    main_menu
}

# ============================================================================
# view_snapshot_details()
#
# Show details for a specific snapshot
# ============================================================================

view_snapshot_details() {
    local snapshot_path="$1"

    if [ ! -d "$snapshot_path" ]; then
        whiptail --msgbox "Error: Snapshot not found" 8 60
        return 1
    fi

    local basename=$(basename "$snapshot_path")
    local snapshot_time=$(echo "$basename" | sed -n 's/openclaw-\([0-9]\{8\}\)-\([0-9]\{6\}\)/\1 \2/p')
    local size=$(get_snapshot_size "$snapshot_path")
    local file_count=$(get_snapshot_file_count "$snapshot_path")

    # Build details text
    local details=""
    details+="Snapshot: $basename\n"
    details+="Path: $snapshot_path\n"
    details+="Size: $size\n"
    details+="Files: $file_count\n"
    details+="\n"
    details+="Recent Events:\n"

    # Get events around this snapshot
    local snap_time="${snapshot_time:0:4}-${snapshot_time:4:2}-${snapshot_time:6:2}T${snapshot_time:9:2}:${snapshot_time:11:2}:00+01:00"
    local next_time=$(date -d "$(date -d "$snap_time" +%s) + 86400 seconds" -Iseconds)

    while IFS='|' read -r timestamp type message; do
        details+="[$type] $message\n"
    done < <(get_events_between "$snap_time" "$next_time" 2>/dev/null | head -10)

    whiptail --title "Snapshot Details" --scrolltext --msgbox "$details" 30 100
}

# ============================================================================
# diff_menu()
#
# Select two snapshots to compare
# ============================================================================

diff_menu() {
    local snapshots=()
    local idx=1

    while IFS='|' read -r timestamp path; do
        snapshots+=("$idx" "$(basename "$path")")
        ((idx++))
    done < <(list_snapshots)

    # Select first snapshot
    local snap1=$(whiptail --title "Diff: Select First Snapshot" \
                           --menu "Select older snapshot:" 20 90 10 \
                           "${snapshots[@]}" \
                           3>&1 1>&2 2>&3)

    [ -z "$snap1" ] && return 0

    # Select second snapshot
    local snap2=$(whiptail --title "Diff: Select Second Snapshot" \
                           --menu "Select newer snapshot:" 20 90 10 \
                           "${snapshots[@]}" \
                           3>&1 1>&2 2>&3)

    [ -z "$snap2" ] && return 0

    # Get paths
    local path1=$(list_snapshots | sed -n "${snap1}p" | cut -d'|' -f2)
    local path2=$(list_snapshots | sed -n "${snap2}p" | cut -d'|' -f2)

    # Show diff in terminal
    clear
    echo -e "${BLUE}=== Snapshot Diff ===${NC}"
    echo "Comparing:"
    echo "  1: $(basename "$path1")"
    echo "  2: $(basename "$path2")"
    echo ""

    diff_snapshots "$path1" "$path2" 2>/dev/null || true

    echo ""
    read -p "Press Enter to continue..."
    main_menu
}

# ============================================================================
# restore_menu()
#
# Select snapshot to restore
# ============================================================================

restore_menu() {
    local snapshots=()
    local idx=1

    while IFS='|' read -r timestamp path; do
        snapshots+=("$idx" "$(basename "$path")")
        ((idx++))
    done < <(list_snapshots)

    local choice=$(whiptail --title "Restore Snapshot" \
                            --menu "⚠️  WARNING: This will restore your configuration!" 20 90 10 \
                            "${snapshots[@]}" \
                            3>&1 1>&2 2>&3)

    [ -z "$choice" ] && return 0

    local snapshot_path=$(list_snapshots | sed -n "${choice}p" | cut -d'|' -f2)

    # Execute restore
    clear
    restore_snapshot "$snapshot_path" || true

    echo ""
    read -p "Press Enter to continue..."
    main_menu
}

# ============================================================================
# show_header()
#
# Display banner and version info
# ============================================================================

show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  OpenClaw Timeline Browser — Snapshot Manager               ║${NC}"
    echo -e "${BLUE}║  \"Git Time Machine for your entire system\"                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

# Check dependencies
for cmd in whiptail find du stat; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

# Show header and start menu loop
show_header
main_menu

# Clean exit
clear
echo -e "${GREEN}✓ Timeline Browser closed${NC}"
exit 0
