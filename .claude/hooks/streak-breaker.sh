#!/bin/bash
# streak-breaker.sh — PreToolUse hook
# Tracks how many times the same file has been edited in this session
# Pauses for reflection when the pattern suggests circling
#
# Design:
#   - Source code files (.java/.ts/.py/.go etc): warn at 3, stop at 5
#   - Config/doc files (.md/.json/.yaml/.xml etc): warn at 6, stop at 10
#   - docs/ directory: exempt (always allow)
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

# Always allow docs/ files (progress logs, debug logs)
if echo "$FILE_PATH" | grep -qE "^docs/|/docs/"; then
    exit 0
fi

# Determine file type and set thresholds
BASENAME=$(basename "$FILE_PATH")

if echo "$BASENAME" | grep -qiE "\.(md|json|yaml|yml|toml|xml|cfg|ini|properties|gitignore)$"; then
    # Config/doc files: higher thresholds (many independent sections to fill)
    WARN_THRESHOLD=6
    STOP_THRESHOLD=10
else
    # Source code files: strict thresholds (repeated edits may indicate circling)
    WARN_THRESHOLD=3
    STOP_THRESHOLD=5
fi

# Counter logic
SAFE_NAME=$(echo "$FILE_PATH" | tr '/' '_')
COUNTER_FILE="$COUNTER_DIR/$SAFE_NAME"
CONFIRMED_FILE="${COUNTER_FILE}.confirmed"

# If user previously confirmed planned edits, double thresholds
if [ -f "$CONFIRMED_FILE" ]; then
    WARN_THRESHOLD=$((WARN_THRESHOLD * 2))
    STOP_THRESHOLD=$((STOP_THRESHOLD * 2))
fi

if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
else
    COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Hard stop: exit 2 + stderr
if [ "$COUNT" -ge "$STOP_THRESHOLD" ]; then
    if [ -f "$CONFIRMED_FILE" ]; then
        RESET_MSG="Thresholds were already doubled. To continue, the user must explicitly confirm again:
  rm \"$CONFIRMED_FILE\" \"$COUNTER_FILE\" && echo confirmed > \"$CONFIRMED_FILE\""
    else
        RESET_MSG="If this is planned work (refactoring, building a complex file), ask the user to confirm. Then run:
  echo confirmed > \"$CONFIRMED_FILE\" && echo 0 > \"$COUNTER_FILE\"
This doubles the thresholds for this file (warn=${WARN_THRESHOLD}x2, stop=${STOP_THRESHOLD}x2)."
    fi
    cat >&2 <<EOF
EDIT CHECKPOINT
File $FILE_PATH has been edited $COUNT times this session.
This may be normal (building a complex file) or a sign of circling (patching symptoms without addressing the root cause).
Reflect:
  1. Are these edits progressing toward a goal, or fixing previous edits?
  2. If progressing: ask the user to confirm, then continue with doubled thresholds.
  3. If fixing previous edits: pause and look for the root cause.
This is a reflection checkpoint, not a productivity limit. If the work is legitimate, confirm and continue — don't reduce scope or defer work to avoid the counter.
$RESET_MSG
EOF
    exit 2
fi

# Warning: exit 0 + JSON stdout with additionalContext
if [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "EDIT NOTE: File $FILE_PATH has been edited $COUNT times. Quick check: are these edits building toward a goal, or fixing previous edits? If building: keep going, you have $((STOP_THRESHOLD - COUNT)) more before a checkpoint. If fixing: pause and look for the root cause. Don't reduce scope or defer work just to avoid the counter."
  }
}
EOF
    exit 0
fi

# Silent allow
exit 0
