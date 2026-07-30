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
        # Downgraded from a hard block (exit 2) to a note, 2026-07-30.
        # As a hard block this combined with 01-debugging Phase 2 to form a trap:
        # follow the rule, write 3 hypotheses into debug-log.md, and you were then
        # forbidden from editing source until 3 were marked confirmed — including
        # for unrelated planned work. It is the "legacy harness scaffolding that
        # adds separate verification steps" Anthropic's Opus 5 guidance calls out.
        # The hypothesis discipline itself stays in rules 00-core §6 / 01-debugging
        # (56 measured wrong-approach incidents); only the enforcement is relaxed.
        cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"DEBUG-LOG NOTE: docs/debug-log.md has $((PENDING - CONFIRMED)) hypotheses still marked pending. If this edit is the fix for one of them, update its status first so the log stays truthful. If this edit is unrelated work, carry on."}}
JSONEOF
        exit 0
    fi
fi

# ─── Large diff warning ───
# Counts `content` too, not just new_string/old_string: Write sends `content`, so
# the previous version silently never fired on a large Write. Has a no-jq path so
# the "every jq read has an else" invariant holds repo-wide (see CLAUDE.md).
if command -v jq &>/dev/null; then
    NEW_LINES=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // ""' | wc -l | tr -d ' ')
    OLD_LINES=$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' | wc -l | tr -d ' ')
else
    # Newlines arrive as the two-character sequence \n inside the JSON string.
    count_lines() {
        c=$(echo "$INPUT" | sed -n -E "s/.*[{,][[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"(.*)\".*/\1/p" \
            | grep -o '[\]n' | wc -l | tr -d ' ')
        echo $((c + 1))
    }
    NEW_LINES=$(count_lines new_string)
    [ "$NEW_LINES" -le 1 ] && NEW_LINES=$(count_lines content)
    OLD_LINES=$(count_lines old_string)
fi
DIFF_LINES=$((NEW_LINES > OLD_LINES ? NEW_LINES : OLD_LINES))
if [ "$DIFF_LINES" -gt 200 ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"LARGE EDIT NOTE: This edit involves ${DIFF_LINES} lines. Consider: is this the minimal change needed? Could it be broken into smaller, more focused edits?\"}}"
    exit 0
fi

# ─── New tool/script detection ───
# When creating a script file via Write, remind to register in CLAUDE.md
# jq-or-sed: the previous jq-only line left TOOL_NAME empty on Windows Git Bash,
# so this detection never fired there. (fixed 2026-07-30)
if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
else
    TOOL_NAME=$(echo "$INPUT" | sed -n -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
fi
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

# Normal source edit: stay silent (exit 0, no output).
# The "list >=3 causes before a bug fix" guidance already lives in the
# always-injected rules (00-core §6, 01-debugging), the hard debug-log block
# above, and post-error-remind. Re-injecting it on EVERY edit fired even on
# planned feature/registration work — redundant noise, removed 2026-06-05.
exit 0
