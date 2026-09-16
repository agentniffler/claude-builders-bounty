#!/bin/bash
# test-hook.sh - Comprehensive test suite for the destructive command blocker hook

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Setup test environment
HOOK_SCRIPT="./.claude/hooks/block-destructive.sh"
LOG_FILE="$HOME/.claude/hooks/blocked.log"
TEMP_LOG="/tmp/test-hook.log"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗ jq is not installed. Please install jq to run tests.${NC}"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Backup original log
if [[ -f "$LOG_FILE" ]]; then
    cp "$LOG_FILE" "${LOG_FILE}.backup"
    > "$LOG_FILE"  # Clear the log for testing
fi

echo -e "${YELLOW}Testing Claude Code Pre-Tool-Use Security Hook${NC}\n"

# Function to test a command (should be blocked)
test_block() {
    local test_name="$1"
    local command="$2"
    
    # Create JSON input similar to Claude Code PreToolUse event
    local json_input=$(jq -n \
        --arg tool "Bash" \
        --arg cmd "$command" \
        --arg project "/test/project" \
        '{
            tool_name: $tool,
            tool_input: { command: $cmd },
            metadata: { project_path: $project }
        }')
    
    # Run the hook
    local output=$(echo "$json_input" | bash "$HOOK_SCRIPT" 2>/dev/null || true)
    
    # Check if the output contains a denial decision
    if echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' &>/dev/null; then
        echo -e "${GREEN}✓ Blocks: $test_name${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Failed to block: $test_name${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Function to test a command (should be allowed)
test_allow() {
    local test_name="$1"
    local command="$2"
    
    # Create JSON input
    local json_input=$(jq -n \
        --arg tool "Bash" \
        --arg cmd "$command" \
        --arg project "/test/project" \
        '{
            tool_name: $tool,
            tool_input: { command: $cmd },
            metadata: { project_path: $project }
        }')
    
    # Run the hook
    local output=$(echo "$json_input" | bash "$HOOK_SCRIPT" 2>/dev/null || true)
    
    # Check if output is empty (no decision = allow)
    if [[ -z "$output" || "$output" == "" ]]; then
        echo -e "${GREEN}✓ Allows: $test_name${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Incorrectly blocked: $test_name${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Run tests for dangerous commands (should be blocked)
echo -e "${YELLOW}Testing Blocked Commands:${NC}"
test_block "rm -rf /tmp/data" "rm -rf /tmp/data"
test_block "rm -rf with multiple args" "rm -rf /tmp/*.log"
test_block "DROP TABLE users" "DROP TABLE users"
test_block "drop table (lowercase)" "drop table users"
test_block "git push --force" "git push --force"
test_block "git push --force origin main" "git push --force origin main"
test_block "TRUNCATE TABLE orders" "TRUNCATE TABLE orders"
test_block "truncate table (lowercase)" "truncate table orders"
test_block "DELETE FROM without WHERE" "DELETE FROM users"
test_block "delete from (lowercase) without where" "delete from users"
test_block "DELETE FROM with semicolon" "DELETE FROM users;"
test_block "DELETE FROM with newline" "DELETE FROM users
  ; DELETE FROM other;"

echo ""
echo -e "${YELLOW}Testing Allowed Commands:${NC}"
test_allow "rm single file" "rm file.txt"
test_allow "rm with -i flag (interactive)" "rm -i *.log"
test_allow "rm -r (not -rf)" "rm -r directory"
test_allow "git push normal" "git push"
test_allow "git push with args" "git push origin main"
test_allow "DELETE FROM with WHERE" "DELETE FROM users WHERE id=1"
test_allow "delete from with where clause" "delete from users where active=false"
test_allow "SELECT query" "SELECT * FROM users"
test_allow "INSERT statement" "INSERT INTO users VALUES (1, 'test')"
test_allow "Update statement" "UPDATE users SET name='test'"
test_block "drop table if exists (lowercase)" "drop table if exists temp_table"

echo ""
echo -e "${YELLOW}Testing Logging:${NC}"

# Test that logging works
if [[ -f "$LOG_FILE" ]]; then
    log_count=$(wc -l < "$LOG_FILE")
    if [[ $log_count -gt 0 ]]; then
        echo -e "${GREEN}✓ Blocked attempts logged to $LOG_FILE${NC}"
        PASSED=$((PASSED + 1))
        echo "  Sample log entries:"
        head -2 "$LOG_FILE" | sed 's/^/    /'
    else
        echo -e "${RED}✗ No log entries found${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠ Log file not created yet (will be created on first block in production)${NC}"
fi

echo ""
echo -e "${YELLOW}Testing Tool Filtering:${NC}"

# Test that non-Bash tools are ignored
json_input=$(jq -n \
    --arg tool "Python" \
    --arg cmd "rm -rf /tmp" \
    '{
        tool_name: $tool,
        tool_input: { command: $cmd },
        metadata: { project_path: "/test" }
    }')

output=$(echo "$json_input" | bash "$HOOK_SCRIPT" 2>/dev/null || true)
if [[ -z "$output" ]]; then
    echo -e "${GREEN}✓ Ignores non-Bash tools${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Incorrectly processed non-Bash tool${NC}"
    FAILED=$((FAILED + 1))
fi

echo ""
echo -e "${YELLOW}Test Summary:${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

# Restore original log
if [[ -f "${LOG_FILE}.backup" ]]; then
    mv "${LOG_FILE}.backup" "$LOG_FILE"
fi

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed.${NC}"
    exit 1
fi
