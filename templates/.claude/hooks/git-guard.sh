#!/bin/bash
# cc-discipline: Guard against destructive git commands
# PreToolUse on Bash — blocks git checkout/restore/reset --hard/clean -f without confirmation.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Normalize: collapse whitespace, trim
CMD_NORM=$(echo "$CMD" | tr '\n' ' ' | sed 's/  */ /g')

BLOCKED=""
SUGGESTION=""

# git checkout . / git checkout -- <file> (discard working tree changes)
# But allow: git checkout <branch>, git checkout -b <branch>
if echo "$CMD_NORM" | grep -qE 'git\s+checkout\s+(\.|--\s)'; then
    BLOCKED="git checkout (discards uncommitted changes)"
    SUGGESTION="git stash"
fi

# git restore . / git restore <file> (without --staged)
if echo "$CMD_NORM" | grep -qE 'git\s+restore\s' && ! echo "$CMD_NORM" | grep -qE 'git\s+restore\s+--staged'; then
    BLOCKED="git restore (discards uncommitted changes)"
    SUGGESTION="git stash"
fi

# git reset --hard
if echo "$CMD_NORM" | grep -qE 'git\s+reset\s+--hard'; then
    BLOCKED="git reset --hard (destroys all uncommitted changes)"
    SUGGESTION="git stash && git reset"
fi

# git clean -f / -fd / -fx
if echo "$CMD_NORM" | grep -qE 'git\s+clean\s+-[a-z]*f'; then
    BLOCKED="git clean -f (permanently deletes untracked files)"
    SUGGESTION="git stash --include-untracked"
fi

# git branch -D (force delete unmerged branch)
if echo "$CMD_NORM" | grep -qE 'git\s+branch\s+-D\s'; then
    BLOCKED="git branch -D (deletes branch even if not merged)"
    SUGGESTION="git branch -d (safe delete, fails if not merged)"
fi

# git push --force / -f (to main/master)
if echo "$CMD_NORM" | grep -qE 'git\s+push\s+.*(-f|--force)' && echo "$CMD_NORM" | grep -qE '(main|master)'; then
    BLOCKED="git push --force to main/master (rewrites shared history)"
    SUGGESTION="git push --force-with-lease"
fi

if [ -n "$BLOCKED" ]; then
    echo "Git safety check: Blocked $BLOCKED. This is an irreversible operation — uncommitted work would be lost. Before proceeding: (1) Check git status and git diff to see what would be affected. (2) If changes should be kept, run: $SUGGESTION first. (3) If you're certain the changes should be discarded, tell the user what will be lost and ask for explicit confirmation." >&2
    exit 2
fi

exit 0
