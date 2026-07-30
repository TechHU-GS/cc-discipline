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

# Read project state
PROGRESS=""
if [ -f "docs/progress.md" ]; then
    PROGRESS=$(tail -20 docs/progress.md)
fi

cat <<'HEADER'
[cc-discipline] Session initialized.
HEADER

if [ -n "$PROGRESS" ]; then
cat <<EOF

Project state (from docs/progress.md):
$PROGRESS

Verify project status by reading files or asking — don't assume beyond what is stated above.
EOF
fi

# Only the skill pointer is injected here. The four rule restatements that used
# to follow it (pre-edit checks, 3-failure rule, confirm-before-implementing,
# verify project state) were removed 2026-07-30: all four are already in the
# rules injected every session (02, 00-core §4, 05, 07 §4a), so repeating them
# here bought nothing. Skills are the one thing rules don't announce.
cat <<'EOF'

/self-check is available for periodic monitoring — for long tasks: /loop 10m /self-check
EOF

exit 0
