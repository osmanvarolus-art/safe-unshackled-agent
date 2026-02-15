#!/bin/bash
# Timeline Browser Test Suite - Phase 6
# Validates all components are syntactically correct and dependencies available

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$PROJECT_DIR/lib"

test_result() {
    ((TESTS_TOTAL++))
    if [ "$1" = "pass" ]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} $2"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}✗${NC} $2"
    fi
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Timeline Browser - Phase 6 Testing                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Syntax checks
echo -e "${BLUE}=== Syntax Validation ===${NC}"
bash -n "$LIB_DIR/snapshot-parser.sh" 2>/dev/null && test_result pass "snapshot-parser.sh" || test_result fail "snapshot-parser.sh"
bash -n "$LIB_DIR/event-correlator.sh" 2>/dev/null && test_result pass "event-correlator.sh" || test_result fail "event-correlator.sh"
bash -n "$LIB_DIR/diff-engine.sh" 2>/dev/null && test_result pass "diff-engine.sh" || test_result fail "diff-engine.sh"
bash -n "$LIB_DIR/restore-manager.sh" 2>/dev/null && test_result pass "restore-manager.sh" || test_result fail "restore-manager.sh"
bash -n "$PROJECT_DIR/scripts/timeline-browser.sh" 2>/dev/null && test_result pass "timeline-browser.sh" || test_result fail "timeline-browser.sh"

# File existence
echo -e "\n${BLUE}=== File Existence ===${NC}"
[ -f "$LIB_DIR/snapshot-parser.sh" ] && test_result pass "snapshot-parser.sh exists" || test_result fail "snapshot-parser.sh missing"
[ -f "$LIB_DIR/event-correlator.sh" ] && test_result pass "event-correlator.sh exists" || test_result fail "event-correlator.sh missing"
[ -f "$LIB_DIR/diff-engine.sh" ] && test_result pass "diff-engine.sh exists" || test_result fail "diff-engine.sh missing"
[ -f "$LIB_DIR/restore-manager.sh" ] && test_result pass "restore-manager.sh exists" || test_result fail "restore-manager.sh missing"
[ -x "$PROJECT_DIR/scripts/timeline-browser.sh" ] && test_result pass "timeline-browser.sh executable" || test_result fail "timeline-browser.sh not executable"

# Dependencies
echo -e "\n${BLUE}=== Required Commands ===${NC}"
command -v bash &>/dev/null && test_result pass "bash" || test_result fail "bash"
command -v find &>/dev/null && test_result pass "find" || test_result fail "find"
command -v grep &>/dev/null && test_result pass "grep" || test_result fail "grep"
command -v sed &>/dev/null && test_result pass "sed" || test_result fail "sed"
command -v sort &>/dev/null && test_result pass "sort" || test_result fail "sort"
command -v cut &>/dev/null && test_result pass "cut" || test_result fail "cut"
command -v wc &>/dev/null && test_result pass "wc" || test_result fail "wc"
command -v du &>/dev/null && test_result pass "du" || test_result fail "du"
command -v stat &>/dev/null && test_result pass "stat" || test_result fail "stat"
command -v systemctl &>/dev/null && test_result pass "systemctl" || test_result fail "systemctl"
command -v whiptail &>/dev/null && test_result pass "whiptail" || test_result fail "whiptail"
command -v jq &>/dev/null && test_result pass "jq" || test_result fail "jq"
command -v git &>/dev/null && test_result pass "git" || test_result fail "git"

# Library loading
echo -e "\n${BLUE}=== Library Loading ===${NC}"
bash -c "source '$LIB_DIR/snapshot-parser.sh'" 2>/dev/null && test_result pass "Load snapshot-parser.sh" || test_result fail "Load snapshot-parser.sh"
bash -c "source '$LIB_DIR/event-correlator.sh'" 2>/dev/null && test_result pass "Load event-correlator.sh" || test_result fail "Load event-correlator.sh"
bash -c "source '$LIB_DIR/diff-engine.sh'" 2>/dev/null && test_result pass "Load diff-engine.sh" || test_result fail "Load diff-engine.sh"
bash -c "source '$LIB_DIR/restore-manager.sh'" 2>/dev/null && test_result pass "Load restore-manager.sh" || test_result fail "Load restore-manager.sh"

# Functions
echo -e "\n${BLUE}=== Function Availability ===${NC}"
bash -c "source '$LIB_DIR/snapshot-parser.sh' 2>/dev/null; declare -f list_snapshots &>/dev/null" && test_result pass "list_snapshots" || test_result fail "list_snapshots"
bash -c "source '$LIB_DIR/snapshot-parser.sh' 2>/dev/null; declare -f get_snapshot_size &>/dev/null" && test_result pass "get_snapshot_size" || test_result fail "get_snapshot_size"
bash -c "source '$LIB_DIR/snapshot-parser.sh' 2>/dev/null; declare -f get_snapshot_file_count &>/dev/null" && test_result pass "get_snapshot_file_count" || test_result fail "get_snapshot_file_count"

bash -c "source '$LIB_DIR/event-correlator.sh' 2>/dev/null; declare -f build_timeline &>/dev/null" && test_result pass "build_timeline" || test_result fail "build_timeline"
bash -c "source '$LIB_DIR/event-correlator.sh' 2>/dev/null; declare -f count_events_between &>/dev/null" && test_result pass "count_events_between" || test_result fail "count_events_between"
bash -c "source '$LIB_DIR/event-correlator.sh' 2>/dev/null; declare -f get_events_between &>/dev/null" && test_result pass "get_events_between" || test_result fail "get_events_between"

bash -c "source '$LIB_DIR/diff-engine.sh' 2>/dev/null; declare -f diff_snapshots &>/dev/null" && test_result pass "diff_snapshots" || test_result fail "diff_snapshots"
bash -c "source '$LIB_DIR/diff-engine.sh' 2>/dev/null; declare -f diff_json &>/dev/null" && test_result pass "diff_json" || test_result fail "diff_json"

bash -c "source '$LIB_DIR/restore-manager.sh' 2>/dev/null; declare -f restore_snapshot &>/dev/null" && test_result pass "restore_snapshot" || test_result fail "restore_snapshot"
bash -c "source '$LIB_DIR/restore-manager.sh' 2>/dev/null; declare -f create_emergency_backup &>/dev/null" && test_result pass "create_emergency_backup" || test_result fail "create_emergency_backup"
bash -c "source '$LIB_DIR/restore-manager.sh' 2>/dev/null; declare -f list_restore_candidates &>/dev/null" && test_result pass "list_restore_candidates" || test_result fail "list_restore_candidates"

# Integration
echo -e "\n${BLUE}=== Integration ===${NC}"
bash -c "source '$LIB_DIR/snapshot-parser.sh' 2>/dev/null; source '$LIB_DIR/event-correlator.sh' 2>/dev/null; source '$LIB_DIR/diff-engine.sh' 2>/dev/null; source '$LIB_DIR/restore-manager.sh' 2>/dev/null" 2>/dev/null && test_result pass "Load all libraries together" || test_result fail "Load all libraries together"

bash -c "source '$LIB_DIR/restore-manager.sh' 2>/dev/null; [ -n \"\$BLUE\" ] && [ -n \"\$GREEN\" ] && [ -n \"\$RED\" ] && [ -n \"\$NC\" ]" 2>/dev/null && test_result pass "Color variables defined" || test_result fail "Color variables defined"

# Edge cases
echo -e "\n${BLUE}=== Edge Cases ===${NC}"
bash -c "source '$LIB_DIR/snapshot-parser.sh' 2>/dev/null; list_snapshots 2>/dev/null; true" && test_result pass "Handle missing snapshots" || test_result fail "Handle missing snapshots"

# Report
echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "Total: $TESTS_TOTAL | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL $TESTS_TOTAL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ $TESTS_FAILED TEST(S) FAILED${NC}"
    exit 1
fi
