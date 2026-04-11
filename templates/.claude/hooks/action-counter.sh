#!/bin/bash
# cc-discipline: Action counter for periodic self-check
# Counts action-type tool calls per session, injects self-check every N actions.
# PreToolUse on Edit|Write|MultiEdit|Bash|Agent — additionalContext injection.

THRESHOLD=25

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
    SESSION_ID="unknown"
fi

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
    CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
    PROGRESS_FILE=""
    [ -f "$CWD/docs/progress.md" ] && PROGRESS_FILE="$CWD/docs/progress.md"
    [ -z "$PROGRESS_FILE" ] && [ -f "docs/progress.md" ] && PROGRESS_FILE="docs/progress.md"
    if [ -n "$PROGRESS_FILE" ]; then
        # Check if file was modified in the last 30 minutes
        if command -v stat &>/dev/null; then
            FILE_MOD=$(stat -f %m "$PROGRESS_FILE" 2>/dev/null || stat -c %Y "$PROGRESS_FILE" 2>/dev/null)
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

if [ $((COUNT % THRESHOLD)) -eq 0 ]; then
    cat <<JSONEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Periodic reflection (#${COUNT} actions): Take a moment to check in. ALIGNMENT: (1) Am I still serving the user's current direction? They may have pivoted — follow their latest intent. (2) Am I making changes the user asked for, and only those? QUALITY: (3) Are all my 'verified' claims backed by actual execution output? If not, correct that now. (4) If executing a plan, does what I delivered match what the step asked for? Check acceptance criteria. (5) Am I maintaining quality, or taking shortcuts to avoid difficulty? If tempted to cut corners, ask the user instead. PROGRESS: (6) Am I progressing or circling? (fixing the same area repeatedly suggests a deeper issue worth stepping back to find) (7) Is docs/progress.md up to date? If auto-compact happened now, could a fresh session resume from it? (8) Did I break a task into subtasks and skip some? If the analysis context is fresh, finishing them now is cheaper than rebuilding later. WHAT'S WORKING: (9) Note one thing going well — a good approach, a clean fix, or effective tool use. (10) Any friction from hooks or rules since last check? Note it for /retro. If any answer is concerning, pause and report to the user before continuing."}}
JSONEOF
fi

exit 0
