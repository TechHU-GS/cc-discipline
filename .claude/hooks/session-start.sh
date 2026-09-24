#!/bin/bash
# cc-discipline: SessionStart hook
# Injects project state + discipline reminders into Claude's context.
# stdout → context (Claude can see and act on it)
# Fires on: startup, resume, clear, compact

# Reset action counter for this session.
# jq-or-sed: jq is absent on Windows Git Bash, and the previous jq-only version
# left SESSION_ID empty there, so the reset below never ran. (fixed 2026-07-30)
INPUT=$(cat)
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
else
    SESSION_ID=$(echo "$INPUT" | sed -n -E 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
fi
if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "unknown" ]; then
    rm -f "/tmp/cc-discipline-${SESSION_ID}/action-count"
fi

# Project state, read from two files, each only if present:
#   docs/progress.md — its "## Current Status" section. This used to be
#     `tail -20`, which injected the end of whichever section happened to be last
#     (the Rule Ledger, or the tail of the newest milestone) and never the status.
#     A progress.md without that heading still falls back to the old tail.
#   docs/todo.md — the "## Now" section in full, and a count of "## Later" items.
#     Later items are counted, not listed: the list can grow long, and /self-check
#     is where their revisit conditions get checked.
# Both files are hand-edited, so CRs are stripped (a CRLF checkout would leave one
# on every line) and HTML comments are dropped. Portable awk only — this has to
# behave the same under macOS's BSD awk. Fails silent: a missing or reshaped file
# injects nothing rather than something misleading.
section() {  # section <file> <heading>: body of "## <heading>" up to the next "## "
    sed 's/\r$//' "$1" 2>/dev/null | awk -v h="## $2" '
        { t = $0; sub(/[ \t]+$/, "", t) }
        tolower(t) == tolower(h) { on = 1; next }
        on && /^## /             { exit }
        on && /^-+[ \t]*$/       { next }
        on && /<!--/             { c = 1 }
        on && !c && NF           { print }
        on && c && /-->/         { c = 0 }'
}

STATUS=""
if [ -f "docs/progress.md" ]; then
    STATUS=$(section docs/progress.md "Current Status" | head -15)
    [ -z "$STATUS" ] && STATUS=$(sed 's/\r$//' docs/progress.md | tail -20)
fi

NOW=""; NOW_MORE=0; LATER=0
if [ -f "docs/todo.md" ]; then
    NOW_ALL=$(section docs/todo.md "Now")
    NOW=$(printf '%s\n' "$NOW_ALL" | head -20)
    NOW_N=$(printf '%s\n' "$NOW_ALL" | grep -c .) || NOW_N=0
    [ "$NOW_N" -gt 20 ] && NOW_MORE=$((NOW_N - 20))
    # An open item is a bullet that isn't ticked: "- [ ] x" or "- x", not "- [x] x".
    LATER=$(section docs/todo.md "Later" | grep -cE '^[[:space:]]*[-*] (\[ \]|[^[])') || LATER=0
fi

cat <<'HEADER'
[cc-discipline] Session initialized.
HEADER

if [ -n "$STATUS" ]; then
    printf '\nProject state (from docs/progress.md):\n%s\n' "$STATUS"
fi
if [ -n "$NOW" ] || [ "$LATER" -gt 0 ]; then
    printf '\nOpen work (from docs/todo.md):\n'
    [ -n "$NOW" ] && printf 'Now:\n%s\n' "$NOW"
    [ "$NOW_MORE" -gt 0 ] && printf '... and %s more under Now.\n' "$NOW_MORE"
    [ "$LATER" -gt 0 ] && printf 'Later: %s item(s), each with a condition for when to revisit it.\n' "$LATER"
fi
if [ -n "$STATUS" ] || [ -n "$NOW" ] || [ "$LATER" -gt 0 ]; then
    printf "\nVerify project status by reading files or asking — don't assume beyond what is stated above.\n"
fi

# Only the skill pointer is injected here. The four rule restatements that used
# to follow it (pre-edit checks, 3-failure rule, confirm-before-implementing,
# verify project state) were removed 2026-07-30 as duplicates of rules injected
# every session (00-core §4, 05, 07 §4a; the pre-edit checks lived in 02, which was
# itself retired 2026-09-23 for duplicating other rules). Skills are the one thing
# rules don't announce.
cat <<'EOF'

/self-check is available for periodic monitoring — for long tasks: /loop 10m /self-check
EOF

exit 0
