#!/bin/bash
# pre-edit-guard.sh — PreToolUse hook
# Checks that Claude has finished debugging before editing source code
#
# Exit 0 + no output = allow edit
# Exit 2 + stderr = block edit, stderr shown to Claude

# Read the tool input from stdin (JSON)
INPUT=$(cat)

# Extract file_path first. Everything past the exemption checks needs more
# fields, but the exemptions need only this one — and in a docs-heavy repo most
# edits exit there, so pulling cwd before deciding whether we care costs ~40ms
# on every edit for nothing. Measured 2026-09-02: concluding "not my business"
# cost 297ms, of which 24ms was the actual decision.
if command -v jq &>/dev/null; then
    HAS_JQ=1
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
    HAS_JQ=0
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')
fi

# Exemptions below use bash builtins only. `case` and parameter expansion fork
# nothing, where `echo | grep` forks two processes and `basename` one. The
# decisions are identical to the greps they replace — see
# tests/pre-edit-guard-matrix.sh, which runs both and compares.

# Allow edits to docs/ — case-SENSITIVE, matching the original grep (no -i).
case "$FILE_PATH" in
    docs/*|*/docs/*) exit 0 ;;
esac

# Just the filename, so directory names cannot cause a false match.
BASENAME=${FILE_PATH##*/}

# Test files and config/meta files. nocasematch reproduces `grep -i`; it is set
# only around these two patterns and unset immediately, so nothing later in the
# script inherits it. Available since bash 3.1, so macOS's stock 3.2 is fine.
shopt -s nocasematch
case "$BASENAME" in
    *test*|*spec*) exit 0 ;;
    *.md|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini) exit 0 ;;
esac
shopt -u nocasematch

# cwd is needed only from here on, past every exemption.
if [ "$HAS_JQ" = 1 ]; then
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
else
    CWD=$(echo "$INPUT" | grep -o '"cwd":\s*"[^"]*"' | head -1 | sed 's/"cwd":\s*"//;s/"//')
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

# The new-script registration reminder was removed 2026-08-28. It fired 2,170
# times in four weeks across two machines (~50 tokens each), almost entirely on
# one-off transform scripts nobody would ever register. The measured correlation
# with a growing Project Tools section was confounded: /commit carries the same
# instruction, and a "does the heading exist" gate was disproven because
# templates/CLAUDE.md ships that heading so every generated project has it.
# Removing the branch also drops the TOOL_NAME extraction, which nothing else
# used, cutting two subprocess calls from the hottest hook.

# Normal source edit: stay silent (exit 0, no output).
# The "list >=3 causes before a bug fix" guidance already lives in the
# always-injected rules (00-core §6, 01-debugging), the hard debug-log block
# above, and post-error-remind. Re-injecting it on EVERY edit fired even on
# planned feature/registration work — redundant noise, removed 2026-06-05.
exit 0
