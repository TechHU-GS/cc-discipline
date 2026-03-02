#!/bin/bash
# pre-edit-guard.sh
# Triggered before Edit/Write/MultiEdit operations
# Checks that Claude is working with intention, not impulse
#
# Exit 0 = allow edit
# Exit 1 = block edit (message shown to Claude)
# Exit 2 = block edit and stop the tool (hard stop)

# Read the tool input from stdin
INPUT=$(cat)

# Extract the file path being edited
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')

# Allow edits to docs/ (progress tracking files should always be writable)
if echo "$FILE_PATH" | grep -q "^docs/\|/docs/"; then
    exit 0
fi

# Allow edits to test files (more permissive)
if echo "$FILE_PATH" | grep -qi "test\|spec\|__test__\|_test\."; then
    exit 0
fi

# Allow edits to config/meta files
if echo "$FILE_PATH" | grep -qi "\.md$\|\.json$\|\.yaml$\|\.yml$\|\.toml$\|\.cfg$\|\.ini$"; then
    exit 0
fi

# Check: if debug-log has unresolved hypotheses and we're editing source code,
# remind Claude to finish the debugging process first
DEBUG_LOG="docs/debug-log.md"
if [ -f "$DEBUG_LOG" ]; then
    # Check for open debugging sessions (has "待验证" without corresponding "已确认")
    PENDING=$(grep -c "待验证" "$DEBUG_LOG" 2>/dev/null || echo "0")
    CONFIRMED=$(grep -c "已确认" "$DEBUG_LOG" 2>/dev/null || echo "0")

    if [ "$PENDING" -gt "$CONFIRMED" ] 2>/dev/null; then
        echo "⚠️ docs/debug-log.md 中有 $((PENDING - CONFIRMED)) 个未验证的假设。"
        echo "请先完成调试流程（验证或排除假设）再修改源码。"
        echo "如果你已确认根因，请先更新 debug-log.md。"
        # Exit 0 anyway - this is a reminder, not a hard block
        # Change to 'exit 1' if you want to enforce strictly
        exit 0
    fi
fi

exit 0
