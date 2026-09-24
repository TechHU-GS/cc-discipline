#!/bin/bash
# Read-only inventory of cc-discipline installs under one code directory.
#
# Enumerates by the marker .claude/hooks/streak-breaker.sh, never by the version
# file (the oldest installs have none), and searches 6 levels deep (installs
# nest: GS_IC/designs/*). For each install prints its version, whether its
# git-guard is the parser (2.14.0+), its origin repository, its last commit
# date, whether it is a detached linked worktree, and its path.
#
# Usage:  bash tools/inventory.sh <code dir>
#   MS-01:        bash tools/inventory.sh /e/Code
#   mac-mini:     ssh techhu@100.64.0.8 'bash -ls -- "$HOME/Code"' < tools/inventory.sh
#   techhu-7940:  ssh techhu_dev@100.64.0.18 '"C:\Program Files\Git\bin\bash.exe" -ls -- /d/Code' < tools/inventory.sh
# (Remote runs need a login shell: without -l, npx and friends are off PATH.)
BASE="${1:?usage: inventory.sh <code dir>}"
LIST=$(find "$BASE" -maxdepth 6 \( -name node_modules -o -name .git \) -prune -o \
        -path '*/.claude/hooks/streak-breaker.sh' -print 2>/dev/null \
        | sed 's#/.claude/hooks/streak-breaker.sh$##' | sort -u)
echo "host=$(hostname) base=$BASE installs=$(printf '%s\n' "$LIST" | grep -c .)"
for d in $LIST; do
    v=$(cat "$d/.claude/.cc-discipline-version" 2>/dev/null | tr -d '\r\n'); [ -n "$v" ] || v=none
    r=$(git -C "$d" remote get-url origin 2>/dev/null | sed 's#\.git$##; s#.*[:/]\([^/]*/[^/]*\)$#\1#')
    last=$(git -C "$d" log -1 --format=%cs 2>/dev/null)
    if grep -q 'judge_git' "$d/.claude/hooks/git-guard.sh" 2>/dev/null; then gg=parser; else gg=old; fi
    wt=""
    if [ "$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)" != "$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]; then
        git -C "$d" symbolic-ref -q HEAD >/dev/null 2>&1 && wt="worktree" || wt="DETACHED-worktree"
    fi
    printf '  %-8s %-7s %-40s %-11s %-18s %s\n' "$v" "$gg" "${r:--}" "${last:--}" "$wt" "${d#$BASE/}"
done
