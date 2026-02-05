#!/usr/bin/env bash
#
# Example hook script: Validate that SQL queries are read-only
# 
# Used by subagents that need to restrict database access to SELECT queries only.
# Exit code 2 blocks the operation and returns the error message to the agent.
#
# Input: JSON via stdin with tool_input.command containing the bash command
# Output: Error message via stderr if blocked
#
# Usage in subagent frontmatter:
#   hooks:
#     PreToolUse:
#       - matcher: "Bash"
#         hooks:
#           - type: command
#             command: "./scripts/validate-query.sh"
#

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command field from tool_input using jq
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# If no command, allow (shouldn't happen, but be safe)
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Block write operations (case-insensitive)
# This catches SQL write operations in various contexts (psql, mysql, sqlite, etc.)
if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|REPLACE|MERGE)\b' > /dev/null; then
    echo "Blocked: Write operations not allowed. Use SELECT queries only." >&2
    exit 2
fi

# Allow the command
exit 0
