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
if echo "$FILE_PATH" | grep -q "^docs/\|/docs/"; then
    exit 0
fi

# Allow edits to test files (match filename only, not directory path)
if echo "$BASENAME" | grep -qi "test\|spec"; then
    exit 0
fi

# Allow edits to config/meta files
if echo "$BASENAME" | grep -qi "\.md$\|\.json$\|\.yaml$\|\.yml$\|\.toml$\|\.cfg$\|\.ini$"; then
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
    PENDING=$(grep -c "待验证" "$DEBUG_LOG" 2>/dev/null) || PENDING=0
    CONFIRMED=$(grep -c "已确认" "$DEBUG_LOG" 2>/dev/null) || CONFIRMED=0

    if [ "$PENDING" -gt "$CONFIRMED" ] 2>/dev/null; then
        cat >&2 <<EOF
⚠️ docs/debug-log.md 中有 $((PENDING - CONFIRMED)) 个未验证的假设。
请先完成调试流程（验证或排除假设）再修改源码。
如果你已确认根因，请先更新 debug-log.md。
EOF
        exit 2
    fi
fi

exit 0
