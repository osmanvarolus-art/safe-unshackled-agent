#!/bin/bash
# Snapshot Parser Library for Timeline Browser
#
# Provides functions to discover and parse snapshot metadata from /home/.snapshots/
#
# Naming convention: {directory}-{YYYYMMDD}-{HHMMSS}
# Example: openclaw-20260215-000005
#
# Functions:
# - list_snapshots()           List all openclaw snapshots with timestamps (newest first)
# - get_snapshot_size()        Get directory size in human-readable format
# - get_snapshot_file_count()  Count files in snapshot directory

set -e

# ============================================================================
# list_snapshots()
#
# Parse all openclaw snapshots from /home/.snapshots/
# Extract timestamps from directory names
# Convert to ISO 8601 format with timezone
# Sort by timestamp (newest first)
#
# Output format: timestamp|path
# Example: 2026-02-15T00:00:05+01:00|/home/.snapshots/openclaw-20260215-000005
# ============================================================================

list_snapshots() {
    local snapshots=()

    # Check if snapshot directory exists
    if [ ! -d /home/.snapshots ]; then
        return 0
    fi

    # Parse all openclaw-* directories
    for dir in /home/.snapshots/openclaw-[0-9]*; do
        if [ ! -d "$dir" ]; then
            continue
        fi

        local basename=$(basename "$dir")

        # Extract timestamp from directory name
        # Format: openclaw-YYYYMMDD-HHMMSS
        # Regex: ^openclaw-(\d{8})-(\d{6})$
        if [[ $basename =~ ^openclaw-([0-9]{8})-([0-9]{6})$ ]]; then
            local yyyymmdd="${BASH_REMATCH[1]}"
            local hhmmss="${BASH_REMATCH[2]}"

            # Parse components
            local year="${yyyymmdd:0:4}"
            local month="${yyyymmdd:4:2}"
            local day="${yyyymmdd:6:2}"
            local hour="${hhmmss:0:2}"
            local min="${hhmmss:2:2}"
            local sec="${hhmmss:4:2}"

            # Convert to ISO 8601 with timezone
            # Format: YYYY-MM-DDTHH:MM:SS+01:00 (CET)
            local iso8601="${year}-${month}-${day}T${hour}:${min}:${sec}+01:00"

            # Add to array: timestamp|path
            snapshots+=("${iso8601}|${dir}")
        fi
    done

    # Sort by timestamp (reverse chronological - newest first)
    printf '%s\n' "${snapshots[@]}" | sort -r
}

# ============================================================================
# get_snapshot_size()
#
# Calculate directory size in human-readable format
# Input: snapshot_dir (full path)
# Output: Human-readable size (e.g., "2.3M", "45K", "1.2G")
# ============================================================================

get_snapshot_size() {
    local snapshot_dir="$1"

    if [ ! -d "$snapshot_dir" ]; then
        echo "0B"
        return 1
    fi

    du -sh "$snapshot_dir" 2>/dev/null | awk '{print $1}' || echo "0B"
}

# ============================================================================
# get_snapshot_file_count()
#
# Count total files in snapshot directory
# Input: snapshot_dir (full path)
# Output: Number of files
# ============================================================================

get_snapshot_file_count() {
    local snapshot_dir="$1"

    if [ ! -d "$snapshot_dir" ]; then
        echo "0"
        return 1
    fi

    find "$snapshot_dir" -type f 2>/dev/null | wc -l || echo "0"
}

# ============================================================================
# get_snapshot_modification_time()
#
# Get directory modification time in ISO 8601 format
# Input: snapshot_dir (full path)
# Output: ISO 8601 timestamp
# ============================================================================

get_snapshot_modification_time() {
    local snapshot_dir="$1"

    if [ ! -d "$snapshot_dir" ]; then
        return 1
    fi

    stat -c '%y' "$snapshot_dir" 2>/dev/null | cut -d' ' -f1,2 | sed 's/ /T/'
}

# ============================================================================
# validate_snapshot_directory()
#
# Check if directory is a valid snapshot
# Input: snapshot_dir (full path)
# Output: 0 if valid, 1 if invalid
# ============================================================================

validate_snapshot_directory() {
    local snapshot_dir="$1"

    # Must be a directory
    if [ ! -d "$snapshot_dir" ]; then
        return 1
    fi

    # Must contain at least some files
    if [ "$(get_snapshot_file_count "$snapshot_dir")" -eq 0 ]; then
        return 1
    fi

    return 0
}

# ============================================================================
# Example usage:
#
# # List all snapshots
# list_snapshots
#
# # Get size of a specific snapshot
# get_snapshot_size /home/.snapshots/openclaw-20260215-000005
#
# # Count files in a snapshot
# get_snapshot_file_count /home/.snapshots/openclaw-20260215-000005
# ============================================================================
