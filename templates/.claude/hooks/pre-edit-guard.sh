#!/bin/bash
# pre-edit-guard.sh — PreToolUse hook
# Checks that Claude has finished debugging before editing source code
#
# Exit 0 + no output = allow edit
# Exit 2 + stderr = block edit, stderr shown to Claude

# Read the tool input from stdin (JSON)
INPUT=$(cat)

# Extract fields
if command -v jq &>/dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
else
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')
    CWD=$(echo "$INPUT" | grep -o '"cwd":\s*"[^"]*"' | head -1 | sed 's/"cwd":\s*"//;s/"//')
fi

# Extract just the filename for pattern matching (avoid false matches on directory names)
BASENAME=$(basename "$FILE_PATH")

# Allow edits to docs/
# Note: use -E (extended regex) for portability — BSD grep (macOS) doesn't support \| in basic mode
if echo "$FILE_PATH" | grep -qE "^docs/|/docs/"; then
    exit 0
fi

# Allow edits to test files (match filename only, not directory path)
if echo "$BASENAME" | grep -qiE "test|spec"; then
    exit 0
fi

# Allow edits to config/meta files
if echo "$BASENAME" | grep -qiE "\.(md|json|yaml|yml|toml|cfg|ini)$"; then
    exit 0
fi

# Check for unresolved hypotheses in debug-log.md
DEBUG_LOG=""
if [ -n "$CWD" ] && [ -f "$CWD/docs/debug-log.md" ]; then
    DEBUG_LOG="$CWD/docs/debug-log.md"
elif [ -f "docs/debug-log.md" ]; then
    DEBUG_LOG="docs/debug-log.md"
fi

if [ -n "$DEBUG_LOG" ]; then
    # Count only in actual table rows, strip HTML comments (both single-line and multi-line)
    CLEAN=$(awk '/<!--.*-->/{next} /<!--/{skip=1} /-->/{skip=0;next} !skip{print}' "$DEBUG_LOG" 2>/dev/null)
    PENDING=$(echo "$CLEAN" | grep -c '| pending |' 2>/dev/null) || PENDING=0
    CONFIRMED=$(echo "$CLEAN" | grep -c '| confirmed |' 2>/dev/null) || CONFIRMED=0

    if [ "$PENDING" -gt "$CONFIRMED" ] 2>/dev/null; then
        cat >&2 <<EOF
docs/debug-log.md has $((PENDING - CONFIRMED)) unverified hypotheses.
Please complete the debugging process (verify or eliminate hypotheses) before editing source code.
If you have confirmed the root cause, update debug-log.md first.
EOF
        exit 2
    fi
fi

# ─── Large diff warning ───
HAS_JQ=false
command -v jq &>/dev/null && HAS_JQ=true

if [ "$HAS_JQ" = true ]; then
    NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')
    OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // ""')
    NEW_LINES=$(echo "$NEW_STRING" | wc -l | tr -d ' ')
    OLD_LINES=$(echo "$OLD_STRING" | wc -l | tr -d ' ')
    DIFF_LINES=$((NEW_LINES > OLD_LINES ? NEW_LINES : OLD_LINES))
    if [ "$DIFF_LINES" -gt 200 ]; then
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"LARGE EDIT NOTE: This edit involves ${DIFF_LINES} lines. Consider: is this the minimal change needed? Could it be broken into smaller, more focused edits?\"}}"
        exit 0
    fi
fi

# ─── New tool/script detection ───
# When creating a script file via Write, remind to register in CLAUDE.md
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$TOOL_NAME" = "Write" ] && echo "$BASENAME" | grep -qiE "\.(sh|py|js|ts|rb|pl)$"; then
    # Check if file already exists (new file = tool creation)
    FULL_PATH="$FILE_PATH"
    if [ ! -f "$FULL_PATH" ]; then
        cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"NEW SCRIPT DETECTED: You are creating $BASENAME. If this is a reusable tool/helper, register it in CLAUDE.md under 'Project Tools' now (path, purpose, usage, date) — capturing it while context is fresh saves time later."}}
JSONEOF
        exit 0
    fi
fi

# ─── Bug-fix sanity check ───
# Inject a lightweight reminder on source file edits:
# "If this is a bug fix, have you eliminated alternative hypotheses?"
# Uses additionalContext (non-blocking) so it doesn't slow down normal edits.
cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"If this edit is a bug fix: have you listed >=3 possible causes and eliminated >=2 with evidence? Thorough elimination before fixing prevents wasted cycles. Use 'possible cause' until elimination evidence confirms the root cause."}}
JSONEOF
exit 0
