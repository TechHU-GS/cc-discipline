#!/bin/bash
# cc-discipline: SessionStart hook
# Injects project state + discipline reminders into Claude's context.
# stdout → context (Claude can see and act on it)
# Fires on: startup, resume, clear, compact

# Reset action counter for this session
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
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

cat <<'EOF'

Reminders:
- /self-check available for periodic monitoring. For complex tasks: /loop 10m /self-check
- Before editing: root cause identified? scope respected? change recorded?
- 3 consecutive failures → pause and regroup with the user
- Confirm the approach with the user before starting implementation
- Verify project state (phase, status, dependencies) by reading files or asking
EOF

exit 0
