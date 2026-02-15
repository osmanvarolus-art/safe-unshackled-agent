#!/bin/bash
# Event Correlator Library for Timeline Browser
#
# Merges all timestamped logs from multiple sources into a unified timeline
#
# Data sources:
# 1. Snapshot log        (~/.mcp-memory/snapshot-openclaw.log)
# 2. Watchdog log        (~/.mcp-memory/oc-watchdog.log)
# 3. Canary log          (~/.mcp-memory/oc-canary.log)
# 4. Git history         (~/.openclaw/.git/)
# 5. Journald            (OpenClaw service logs)
#
# Functions:
# - build_timeline()         Parse all sources, merge, sort by timestamp
# - count_events_between()   Count events in time range

set -e

# Colors for output (from audit-openclaw.sh)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# parse_snapshot_log()
#
# Parse snapshot creation events from ~/.mcp-memory/snapshot-openclaw.log
# Format: [TIMESTAMP] ✓ Snapshot created: PATH
# Output: timestamp|SNAPSHOT|message
# ============================================================================

parse_snapshot_log() {
    local log_file="$HOME/.mcp-memory/snapshot-openclaw.log"

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    grep "Snapshot created:" "$log_file" 2>/dev/null | while IFS= read -r line; do
        # Extract timestamp: [2026-02-15T00:00:05+01:00]
        local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')

        # Extract snapshot name
        local snapshot=$(echo "$line" | sed -n 's/.*Snapshot created: \(.*\)/\1/p' | xargs basename 2>/dev/null)

        if [ -n "$timestamp" ]; then
            echo "${timestamp}|SNAPSHOT|Snapshot created: ${snapshot}"
        fi
    done
}

# ============================================================================
# parse_watchdog_log()
#
# Parse watchdog alerts from ~/.mcp-memory/oc-watchdog.log
# Format: [TIMESTAMP] ALERT TRIGGERED: REASON
# Output: timestamp|WATCHDOG|message
# ============================================================================

parse_watchdog_log() {
    local log_file="$HOME/.mcp-memory/oc-watchdog.log"

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    grep "ALERT TRIGGERED\|WARNING" "$log_file" 2>/dev/null | while IFS= read -r line; do
        # Extract timestamp
        local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')

        # Extract message (everything after the timestamp)
        local message=$(echo "$line" | sed -n 's/^\[[^]]*\] *\(.*\)/\1/p')

        if [ -n "$timestamp" ]; then
            echo "${timestamp}|WATCHDOG|${message}"
        fi
    done
}

# ============================================================================
# parse_canary_log()
#
# Parse canary (honeypot) triggers from ~/.mcp-memory/oc-canary.log
# Format: [TIMESTAMP] CANARY TRIGGERED
# Output: timestamp|CANARY|message
# ============================================================================

parse_canary_log() {
    local log_file="$HOME/.mcp-memory/oc-canary.log"

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    grep "CANARY TRIGGERED" "$log_file" 2>/dev/null | while IFS= read -r line; do
        # Extract timestamp
        local timestamp=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p')

        # Extract file that was accessed (next line usually contains "File:")
        if [ -n "$timestamp" ]; then
            echo "${timestamp}|CANARY|Honeypot access detected (credential theft attempt)"
        fi
    done
}

# ============================================================================
# parse_git_log()
#
# Parse git commit history from ~/.openclaw/.git/
# Format: git log --format='%aI|%h|%s'
# Output: timestamp|GIT|message
# ============================================================================

parse_git_log() {
    if [ ! -d "$HOME/.openclaw/.git" ]; then
        return 0
    fi

    git -C "$HOME/.openclaw" log --format='%aI|%h|%s' --since="30 days ago" 2>/dev/null | \
        while IFS='|' read -r timestamp hash message; do
            if [ -n "$timestamp" ]; then
                echo "${timestamp}|GIT|${message} (${hash})"
            fi
        done
}

# ============================================================================
# parse_journald_log()
#
# Parse OpenClaw service logs from journald
# Output: timestamp|JOURNAL|message
# ============================================================================

parse_journald_log() {
    # Query journald for OpenClaw service logs (last 7 days)
    # Filter for important events: service started, restarted, failed
    journalctl --user -u openclaw --output=json --since="7 days ago" 2>/dev/null | \
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                continue
            fi

            # Extract timestamp (microseconds)
            local ts_microsec=$(echo "$line" | grep -o '"__REALTIME_TIMESTAMP":"[^"]*"' | cut -d'"' -f4)

            # Extract message
            local message=$(echo "$line" | grep -o '"MESSAGE":"[^"]*"' | cut -d'"' -f4)

            if [ -z "$ts_microsec" ] || [ -z "$message" ]; then
                continue
            fi

            # Convert microseconds to seconds
            local ts_sec=$((ts_microsec / 1000000))

            # Convert to ISO 8601
            local iso_timestamp=$(date -d "@$ts_sec" -Iseconds 2>/dev/null)

            # Filter for important messages
            if echo "$message" | grep -qE "listening on ws|Started|restarted|failed"; then
                if [ -n "$iso_timestamp" ]; then
                    echo "${iso_timestamp}|JOURNAL|${message}"
                fi
            fi
        done
}

# ============================================================================
# build_timeline()
#
# Merge all timestamped events from 5 sources
# Parse each source, combine, sort by timestamp (reverse chronological)
# Output: timestamp|type|message (sorted newest first)
#
# Example output:
# 2026-02-15T00:30:22+01:00|WATCHDOG|Alert: Memory usage high
# 2026-02-15T00:20:15+01:00|GIT|Update config (abc123d)
# 2026-02-15T00:15:05+01:00|SNAPSHOT|Snapshot created: openclaw-20260215-001505
# ============================================================================

build_timeline() {
    local events=()

    # Parse all 5 sources
    while IFS= read -r line; do
        [ -n "$line" ] && events+=("$line")
    done < <(parse_snapshot_log)

    while IFS= read -r line; do
        [ -n "$line" ] && events+=("$line")
    done < <(parse_watchdog_log)

    while IFS= read -r line; do
        [ -n "$line" ] && events+=("$line")
    done < <(parse_canary_log)

    while IFS= read -r line; do
        [ -n "$line" ] && events+=("$line")
    done < <(parse_git_log)

    while IFS= read -r line; do
        [ -n "$line" ] && events+=("$line")
    done < <(parse_journald_log)

    # Sort by timestamp (reverse chronological - newest first)
    printf '%s\n' "${events[@]}" | sort -r
}

# ============================================================================
# count_events_between()
#
# Count events within a time range
# Input: start_time end_time (ISO 8601 format)
# Output: event count
#
# Example: count_events_between "2026-02-14T00:00:00+01:00" "2026-02-15T00:00:00+01:00"
# ============================================================================

count_events_between() {
    local start_time="$1"
    local end_time="$2"

    if [ -z "$start_time" ] || [ -z "$end_time" ]; then
        echo "0"
        return 1
    fi

    build_timeline | awk -F'|' \
        -v start="$start_time" \
        -v end="$end_time" '
        $1 >= start && $1 <= end { count++ }
        END { if (count) print count; else print 0 }
    '
}

# ============================================================================
# get_events_between()
#
# Get all events within a time range
# Input: start_time end_time (ISO 8601 format)
# Output: timestamp|type|message (one per line)
# ============================================================================

get_events_between() {
    local start_time="$1"
    local end_time="$2"

    if [ -z "$start_time" ] || [ -z "$end_time" ]; then
        return 1
    fi

    build_timeline | awk -F'|' \
        -v start="$start_time" \
        -v end="$end_time" '
        $1 >= start && $1 <= end { print $0 }
    '
}

# ============================================================================
# format_event_for_display()
#
# Format event for TUI display with colors
# Input: timestamp|type|message
# Output: [TYPE] message (with color)
# ============================================================================

format_event_for_display() {
    local line="$1"
    local type=$(echo "$line" | cut -d'|' -f2)
    local message=$(echo "$line" | cut -d'|' -f3-)

    case "$type" in
        SNAPSHOT) echo -e "${GREEN}[${type}]${NC} ${message}" ;;
        WATCHDOG) echo -e "${YELLOW}[${type}]${NC} ${message}" ;;
        CANARY)   echo -e "${RED}[${type}]${NC} ${message}" ;;
        GIT)      echo -e "${BLUE}[${type}]${NC} ${message}" ;;
        JOURNAL)  echo -e "${BLUE}[${type}]${NC} ${message}" ;;
        *)        echo "[${type}] ${message}" ;;
    esac
}

# ============================================================================
# Example usage:
#
# # Build full timeline
# build_timeline
#
# # Count events in time range
# count_events_between "2026-02-14T00:00:00+01:00" "2026-02-15T00:00:00+01:00"
#
# # Get events in range
# get_events_between "2026-02-14T00:00:00+01:00" "2026-02-15T00:00:00+01:00" | head -10
#
# # Format for display
# build_timeline | head -1 | while read line; do format_event_for_display "$line"; done
# ============================================================================
