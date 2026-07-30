#!/bin/bash
# cc-discipline: Action counter for periodic self-check
# Counts action-type tool calls per session, injects self-check every N actions.
# PreToolUse on Edit|Write|MultiEdit|Bash|Agent — additionalContext injection.

INPUT=$(cat)
# Extract session_id with a grep fallback for when jq is unavailable (e.g.
# Windows Git Bash). Without this fallback, every session collapsed to the
# literal "unknown" and shared ONE never-resetting global counter — which
# permanently disabled the early-action phase check (count never restarted
# at 1) and made the periodic reflection fire off a global tally. (fixed 2026-06-05)
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
else
    SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":\s*"[^"]*"' | head -1 | sed 's/"session_id":\s*"//;s/"//')
fi
SESSION_ID="${SESSION_ID:-unknown}"

COUNT_DIR="/tmp/cc-discipline-${SESSION_ID}"
COUNT_FILE="${COUNT_DIR}/action-count"
mkdir -p "$COUNT_DIR"

COUNT=$(cat "$COUNT_FILE" 2>/dev/null) || COUNT=0
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

# Early-action phase check: first 3 actions get a planning reminder
if [ "$COUNT" -le 3 ]; then
    cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Phase check (action #${COUNT}): Before writing code: (1) Have you completed research/understanding? (2) Has the user approved an approach? For non-trivial tasks, planning first ensures alignment and avoids rework."}}
JSONEOF
    exit 0
fi

# Progress.md staleness check: every 50 actions, check if progress.md was updated recently
if [ $((COUNT % 50)) -eq 0 ]; then
    if command -v jq &>/dev/null; then
        CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
    else
        CWD=$(echo "$INPUT" | sed -n -E 's/.*"cwd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1 | sed 's/[\][\]/\//g')
    fi
    PROGRESS_FILE=""
    [ -f "$CWD/docs/progress.md" ] && PROGRESS_FILE="$CWD/docs/progress.md"
    [ -z "$PROGRESS_FILE" ] && [ -f "docs/progress.md" ] && PROGRESS_FILE="docs/progress.md"
    if [ -n "$PROGRESS_FILE" ]; then
        # Check if file was modified in the last 30 minutes.
        # GNU stat (Linux, Windows Git Bash) FIRST, BSD stat (macOS) second —
        # this order matters and the reverse is broken: in GNU stat, `-f` is not
        # BSD's "format" flag, it means "show filesystem status". It therefore
        # SUCCEEDS on Git Bash and prints a multi-line filesystem dump, so the
        # `||` fallback never ran and $((NOW - FILE_MOD)) died with "syntax error
        # in expression". `stat -c` is simply an invalid option on macOS, so it
        # fails cleanly and falls through. The numeric guard below makes the
        # failure mode silent either way. (fixed 2026-07-30)
        if command -v stat &>/dev/null; then
            FILE_MOD=$(stat -c %Y "$PROGRESS_FILE" 2>/dev/null || stat -f %m "$PROGRESS_FILE" 2>/dev/null)
            case "$FILE_MOD" in
                ''|*[!0-9]*) FILE_MOD="" ;;
            esac
            NOW=$(date +%s)
            if [ -n "$FILE_MOD" ] && [ $((NOW - FILE_MOD)) -gt 1800 ]; then
                STALE_MIN=$(( (NOW - FILE_MOD) / 60 ))
                cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Progress check (${STALE_MIN}min since last update): docs/progress.md hasn't been updated in over 30 minutes. If auto-compact happens, recent work context would need to be rebuilt. A quick update to the Working Context section (key commands, current workflow, tools developed, environment state, gotchas) takes 2 minutes and saves hours of re-discovery."}}
JSONEOF
                exit 0
            fi
        fi
    fi
fi

# The 25-action, 10-question "Periodic reflection" block was removed 2026-07-30.
# Anthropic's Opus 5 guidance: the model verifies its own work without being told
# to, and "legacy harness scaffolding that adds separate verification steps"
# causes over-verification — it compounds with the model's own behavior and adds
# cost with no quality gain. The block also duplicated rules already injected
# every session (00-core, 03, 06, 07), at ~299 tokens per firing. The remaining
# checks above (early-action phase check, progress.md staleness) are kept: both
# came out of the 112-session insights analysis in v2.4.0 and target failure
# modes we actually measured, not generic self-review.

exit 0
