#!/bin/bash
# cc-discipline: Phase gate hook
# Injects reminder when Claude attempts to exit plan mode.
# PreToolUse on ExitPlanMode — additionalContext injection, non-blocking.

cat <<'JSONEOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Plan mode exit check: Before starting implementation, confirm: (1) Has the user explicitly approved this plan? (2) Are all key assumptions listed and verified? (3) Is the scope clearly bounded? If the user hasn't approved yet, present the plan for review first."}}
JSONEOF

exit 0
