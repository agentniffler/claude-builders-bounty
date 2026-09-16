#!/bin/bash
# .claude/hooks/block-destructive.sh
# Pre-tool-use hook that blocks destructive bash commands
# Blocks: rm -rf, DROP TABLE, git push --force, TRUNCATE, DELETE FROM (without WHERE)

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract the tool name and command
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
PROJECT_PATH=$(echo "$INPUT" | jq -r '.metadata.project_path // ""')

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
LOG_DIR="$HOME/.claude/hooks"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/blocked.log"

# Function to block command and log it
block_command() {
    local reason="$1"
    
    # Log the blocked attempt
    echo "[$TIMESTAMP] BLOCKED: $reason | Command: $COMMAND | Project: $PROJECT_PATH" >> "$LOG_FILE"
    
    # Return denial decision as JSON
    jq -n --arg reason "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
}

# Only check Bash and PowerShell commands
if [[ "$TOOL_NAME" != "Bash" && "$TOOL_NAME" != "PowerShell" ]]; then
    exit 0
fi

# Normalize command to uppercase for SQL checks
COMMAND_UPPER=$(echo "$COMMAND" | tr '[:lower:]' '[:upper:]')

# Check for destructive patterns
if echo "$COMMAND" | grep -qE 'rm\s+-rf'; then
    block_command "Destructive command blocked: rm -rf is not allowed. This would permanently delete files."
fi

if echo "$COMMAND_UPPER" | grep -qE 'DROP\s+TABLE'; then
    block_command "Destructive SQL command blocked: DROP TABLE is not allowed. This would destroy database tables."
fi

if echo "$COMMAND" | grep -qE 'git\s+push\s+--force'; then
    block_command "Dangerous git command blocked: git push --force is not allowed. This overwrites repository history."
fi

if echo "$COMMAND_UPPER" | grep -qE 'TRUNCATE\s+TABLE'; then
    block_command "Destructive SQL command blocked: TRUNCATE TABLE is not allowed. This would delete all table data."
fi

# Check for DELETE FROM without WHERE clause
# Match DELETE FROM but ensure there's no WHERE clause following it
if echo "$COMMAND_UPPER" | grep -qE 'DELETE\s+FROM'; then
    # Extract the DELETE statement (simplified - stops at semicolon or end of command)
    DELETE_STMT=$(echo "$COMMAND_UPPER" | grep -oE 'DELETE\s+FROM[^;]*' | head -1)
    
    if [[ -n "$DELETE_STMT" ]]; then
        # Check if WHERE is NOT in the statement
        if ! echo "$DELETE_STMT" | grep -qi '\sWHERE\s'; then
            block_command "Destructive SQL command blocked: DELETE FROM without WHERE clause is not allowed. This would delete all records from the table."
        fi
    fi
fi

# If no dangerous patterns matched, exit with code 0 (no decision)
exit 0
