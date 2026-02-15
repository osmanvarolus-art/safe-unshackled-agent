#!/bin/bash
# Diff Engine Library for Timeline Browser
#
# Computes and displays differences between two snapshots
#
# Functions:
# - diff_snapshots()        File-level diff between two snapshots
# - diff_json()            JSON-aware diff for JSON files
# - diff_openclaw_json()   Detailed OpenClaw config diff

set -e

# Colors (from audit-openclaw.sh)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# diff_snapshots()
#
# Compare two snapshot directories and show file-level changes
# Input: older_snapshot_path newer_snapshot_path
# Output: Colored diff summary
#
# Shows:
# - Added files (in newer, not in older)    [GREEN]
# - Removed files (in older, not in newer)  [RED]
# - Modified files (in both, different)     [YELLOW]
# ============================================================================

diff_snapshots() {
    local snap_old="$1"
    local snap_new="$2"

    if [ ! -d "$snap_old" ] || [ ! -d "$snap_new" ]; then
        echo -e "${RED}Error: One or both snapshot directories don't exist${NC}"
        return 1
    fi

    echo -e "${BLUE}=== Comparing Snapshots ===${NC}"
    echo "Older:  $(basename "$snap_old")"
    echo "Newer:  $(basename "$snap_new")"
    echo ""

    # Find all files in both snapshots
    local files_old=$(find "$snap_old" -type f 2>/dev/null | sed "s|$snap_old/||" | sort)
    local files_new=$(find "$snap_new" -type f 2>/dev/null | sed "s|$snap_new/||" | sort)

    # Display added files
    echo -e "${GREEN}Added Files:${NC}"
    comm -13 <(echo "$files_old") <(echo "$files_new") | while read -r file; do
        if [ -n "$file" ]; then
            echo -e "${GREEN}+ ${file}${NC}"
        fi
    done | head -20

    echo ""

    # Display removed files
    echo -e "${RED}Removed Files:${NC}"
    comm -23 <(echo "$files_old") <(echo "$files_new") | while read -r file; do
        if [ -n "$file" ]; then
            echo -e "${RED}- ${file}${NC}"
        fi
    done | head -20

    echo ""

    # Display modified files
    echo -e "${YELLOW}Modified Files:${NC}"
    comm -12 <(echo "$files_old") <(echo "$files_new") | while read -r file; do
        if [ -n "$file" ]; then
            local file_old="$snap_old/$file"
            local file_new="$snap_new/$file"

            # Skip binary files (compare sizes/mtimes instead)
            if ! file "$file_old" | grep -q "text\|JSON"; then
                continue
            fi

            # Compare files
            if ! diff -q "$file_old" "$file_new" &>/dev/null; then
                echo -e "${YELLOW}M ${file}${NC}"

                # If it's JSON, show key changes
                if [[ "$file" == *.json ]]; then
                    echo -e "  ${BLUE}JSON changes:${NC}"
                    diff_json "$file_old" "$file_new" | sed 's/^/    /'
                fi
            fi
        fi
    done | head -40

    echo ""
    echo -e "${BLUE}Legend: ${GREEN}+ Added${NC} ${RED}- Removed${NC} ${YELLOW}M Modified${NC}"
}

# ============================================================================
# diff_json()
#
# JSON-aware diff using jq for key-level comparison
# Input: file1 file2 (both JSON files)
# Output: Key changes highlighted
# ============================================================================

diff_json() {
    local file1="$1"
    local file2="$2"

    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        return 1
    fi

    # Validate JSON files
    if ! jq empty "$file1" 2>/dev/null || ! jq empty "$file2" 2>/dev/null; then
        return 1
    fi

    # Normalize JSON with jq (sorted keys)
    local json1=$(jq -S . "$file1" 2>/dev/null)
    local json2=$(jq -S . "$file2" 2>/dev/null)

    # Diff the normalized JSON
    diff <(echo "$json1") <(echo "$json2") 2>/dev/null | \
        grep '^[<>]' | \
        head -15 | \
        while read -r line; do
            if [[ "$line" =~ ^\< ]]; then
                echo -e "${RED}${line}${NC}"
            elif [[ "$line" =~ ^\> ]]; then
                echo -e "${GREEN}${line}${NC}"
            fi
        done
}

# ============================================================================
# diff_openclaw_json()
#
# Special handling for openclaw.json - show config value changes
# Input: file1 file2 (both openclaw.json)
# Output: Highlighted config changes
# ============================================================================

diff_openclaw_json() {
    local file1="$1"
    local file2="$2"

    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        return 1
    fi

    echo -e "${BLUE}OpenClaw Configuration Changes:${NC}"

    # Extract top-level config keys and their values
    local keys=$(jq -r 'keys[]' "$file1" 2>/dev/null | head -20)

    for key in $keys; do
        local val1=$(jq -r ".$key | @json" "$file1" 2>/dev/null)
        local val2=$(jq -r ".$key | @json" "$file2" 2>/dev/null)

        if [ "$val1" != "$val2" ]; then
            echo -e "${YELLOW}  $key:${NC}"
            echo -e "    ${RED}  - $val1${NC}"
            echo -e "    ${GREEN}  + $val2${NC}"
        fi
    done
}

# ============================================================================
# count_file_changes()
#
# Count the number of files added, removed, modified
# Input: older_snapshot_path newer_snapshot_path
# Output: "added:X removed:Y modified:Z"
# ============================================================================

count_file_changes() {
    local snap_old="$1"
    local snap_new="$2"

    if [ ! -d "$snap_old" ] || [ ! -d "$snap_new" ]; then
        echo "0:0:0"
        return 1
    fi

    local files_old=$(find "$snap_old" -type f 2>/dev/null | sed "s|$snap_old/||" | sort)
    local files_new=$(find "$snap_new" -type f 2>/dev/null | sed "s|$snap_new/||" | sort)

    local added=$(comm -13 <(echo "$files_old") <(echo "$files_new") | wc -l)
    local removed=$(comm -23 <(echo "$files_old") <(echo "$files_new") | wc -l)
    local modified=0

    # Count modified files
    comm -12 <(echo "$files_old") <(echo "$files_new") | while read -r file; do
        if [ -n "$file" ]; then
            if ! diff -q "$snap_old/$file" "$snap_new/$file" &>/dev/null 2>&1; then
                ((modified++))
            fi
        fi
    done

    echo "added:$added removed:$removed modified:$modified"
}

# ============================================================================
# get_largest_changes()
#
# Find files with largest changes (size differences)
# Input: older_snapshot_path newer_snapshot_path
# Output: Files with largest size changes
# ============================================================================

get_largest_changes() {
    local snap_old="$1"
    local snap_new="$2"

    if [ ! -d "$snap_old" ] || [ ! -d "$snap_new" ]; then
        return 1
    fi

    local files_old=$(find "$snap_old" -type f 2>/dev/null | sed "s|$snap_old/||" | sort)
    local files_new=$(find "$snap_new" -type f 2>/dev/null | sed "s|$snap_new/||" | sort)

    # Compare file sizes
    comm -12 <(echo "$files_old") <(echo "$files_new") | while read -r file; do
        if [ -n "$file" ]; then
            local size_old=$(stat -c%s "$snap_old/$file" 2>/dev/null || echo 0)
            local size_new=$(stat -c%s "$snap_new/$file" 2>/dev/null || echo 0)
            local diff=$((size_new - size_old))

            if [ "$diff" -ne 0 ]; then
                echo "$diff|$file"
            fi
        fi
    done | sort -rn | head -10 | while read -r line; do
        local diff=$(echo "$line" | cut -d'|' -f1)
        local file=$(echo "$line" | cut -d'|' -f2)

        if [ "$diff" -gt 0 ]; then
            echo -e "${GREEN}+$(numfmt --to=iec $diff 2>/dev/null || echo ${diff}B) ${file}${NC}"
        else
            echo -e "${RED}$(numfmt --to=iec $diff 2>/dev/null || echo ${diff}B) ${file}${NC}"
        fi
    done
}

# ============================================================================
# Example usage:
#
# # Basic diff between two snapshots
# diff_snapshots /home/.snapshots/openclaw-20260214-* /home/.snapshots/openclaw-20260215-*
#
# # JSON diff
# diff_json /home/.snapshots/openclaw-20260214-*/openclaw.json /home/.snapshots/openclaw-20260215-*/openclaw.json
#
# # Count changes
# count_file_changes /home/.snapshots/openclaw-20260214-* /home/.snapshots/openclaw-20260215-*
# ============================================================================
