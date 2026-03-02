#!/bin/bash
# streak-breaker.sh — PreToolUse hook
# Tracks how many times the same file has been edited in this session
# Forces a stop when the pattern suggests mole-whacking
#
# Exit 0 + no output = silent allow
# Exit 0 + JSON stdout = allow with context injected to Claude
# Exit 2 + stderr = block operation, stderr shown to Claude

# Read tool input from stdin (JSON)
INPUT=$(cat)

# Extract session_id and file_path
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
    SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":\s*"[^"]*"' | head -1 | sed 's/"session_id":\s*"//;s/"//')
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')
fi

SESSION_ID="${SESSION_ID:-unknown-session}"
COUNTER_DIR="/tmp/cc-discipline-${SESSION_ID}"
mkdir -p "$COUNTER_DIR" 2>/dev/null

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Allow docs/ files
if echo "$FILE_PATH" | grep -q "^docs/\|/docs/"; then
    exit 0
fi

# Counter logic
SAFE_NAME=$(echo "$FILE_PATH" | tr '/' '_')
COUNTER_FILE="$COUNTER_DIR/$SAFE_NAME"

if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
else
    COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

WARN_THRESHOLD=3
STOP_THRESHOLD=5

# Hard stop: exit 2 + stderr
if [ "$COUNT" -ge "$STOP_THRESHOLD" ]; then
    cat >&2 <<EOF
MOLE-WHACKING ALERT (hard stop)
File $FILE_PATH has been edited $COUNT times.
You are repeatedly patching symptoms instead of solving the root cause.
Required actions:
  1. Stop editing this file immediately
  2. Review the purpose of all $COUNT edits
  3. Look for the common root cause
  4. Report findings to the user and wait for guidance
To reset: after user confirms direction, delete $COUNTER_FILE to reset the counter
EOF
    exit 2
fi

# Warning: exit 0 + JSON stdout with additionalContext
if [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "WARNING: File $FILE_PATH has been edited $COUNT times. Are you mole-whacking? Do these edits point to the same root cause? $((STOP_THRESHOLD - COUNT)) more edits will trigger a hard stop."
  }
}
EOF
    exit 0
fi

# Silent allow
exit 0
