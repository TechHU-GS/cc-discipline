#!/bin/bash
# cc-discipline: Guard against destructive git commands
# PreToolUse on Bash — blocks git checkout/restore/reset --hard/clean -f without confirmation.

INPUT=$(cat)

# Extract tool_name and command. MUST have a jq-or-grep fallback: jq is absent
# on Windows Git Bash, and the previous jq-only version left TOOL_NAME empty
# there, so the `!= "Bash"` check below exited 0 immediately and EVERY guard in
# this file was dead code. Destructive-git protection never ran on Windows.
# (fixed 2026-07-30 — verified with jq absent, see docs/progress.md)
if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
else
    TOOL_NAME=$(echo "$INPUT" | sed -n -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
    # The [{,] anchor makes this pick the real "command" field rather than an
    # escaped \"command\" nested inside it (happens when piping JSON to a hook).
    # Unescape \n and \" so line-spanning commands still match the patterns below.
    CMD=$(echo "$INPUT" | sed -n -E 's/.*[{,][[:space:]]*"command"[[:space:]]*:[[:space:]]*"(.*)".*/\1/p' \
        | sed 's/[\]n/ /g; s/[\]"/"/g')
    # If the command could not be isolated, scan the whole payload instead of
    # giving up. For a destructive-git guard the failure directions are not
    # symmetric: a spurious confirmation prompt costs one turn, a miss costs the
    # user's uncommitted work. Fail loud.
    [ -z "$CMD" ] && CMD="$INPUT"
fi

# Only gate on tool_name when it actually resolved — an unresolvable tool_name
# must not silently disable the guard (that was the original bug).
if [ -n "$TOOL_NAME" ] && [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Normalize: collapse whitespace, trim
CMD_NORM=$(echo "$CMD" | tr '\n' ' ' | sed 's/  */ /g')

# This guard matches command TEXT, so a command that merely quotes a destructive
# command trips it. The one recurring legitimate case is feeding JSON into one of
# these hooks to test them (the workflow documented in CLAUDE.md). Exempt it —
# piping a payload to a hook script never touches the working tree.
if echo "$CMD_NORM" | grep -qE 'hooks[/\\][a-z-]+\.sh'; then
    exit 0
fi

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
