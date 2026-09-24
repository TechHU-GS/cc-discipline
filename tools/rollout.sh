#!/bin/bash
# Roll a packed release out to the APPROVED installs under one code directory,
# verify each functionally, and surface the installer's "Needs your attention"
# block verbatim.
#
# Usage:  bash tools/rollout.sh <tarball> <code dir> "<approved paths, relative to the dir, space-separated>"
#   Run tools/inventory.sh first and have the user approve the list.
#   Remote:  ssh techhu@100.64.0.8 'bash -ls -- /tmp/x.tgz "$HOME/Code" "a b c"' < tools/rollout.sh
#            ssh techhu_dev@100.64.0.18 '"C:\Program Files\Git\bin\bash.exe" -ls -- C:/Users/techhu_dev/x.tgz /d/Code "a b c"' < tools/rollout.sh
#
# Rules this script enforces (see CLAUDE.md → Rollout):
#   - only approved installs are touched; anything else found is reported and
#     skipped (a worktree made 13 minutes earlier was upgraded unasked on
#     2026-09-24), and approved installs that are missing are named;
#   - detached linked worktrees are skipped even when approved;
#   - installs go through `npx --package=<tgz>` (a bare Windows path is a no-op);
#   - npx gets stdin from /dev/null so it cannot eat the loop's input;
#   - each result is verified by feeding git-guard five payloads, not by
#     grepping files; a failed upgrade keeps its log in .claude/.
TGZ="${1:?usage: rollout.sh <tarball> <code dir> <approved list>}"; BASE="${2:?code dir}"; APPROVED=" ${3:?approved list} "
# Read through stdin: given a "C:/..." path, GNU tar takes "C:" for a remote host.
WANT=$(gzip -dc < "$TGZ" 2>/dev/null | tar xf - -O package/package.json 2>/dev/null | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')
[ -n "$WANT" ] || { echo "cannot read the version from $TGZ"; exit 1; }
LIST=$(find "$BASE" -maxdepth 6 \( -name node_modules -o -name .git \) -prune -o \
        -path '*/.claude/hooks/streak-breaker.sh' -print 2>/dev/null \
        | sed 's#/.claude/hooks/streak-breaker.sh$##' | sort -u \
        | grep -v -e '/cc-discipline$' -e '/cc-discipline/templates$' -e '/_private-reference/')
echo "host=$(hostname) version=$WANT found=$(printf '%s\n' "$LIST" | grep -c .) approved=$(echo $APPROVED | wc -w | tr -d ' ')"
t() { printf '%s' "$2" | bash "$1" >/dev/null 2>&1; [ $? = "$3" ] && printf 'ok' || printf 'FAIL'; }
P1='{"tool_name":"Bash","tool_input":{"command":"git -C repo reset --hard"}}'
P2='{"tool_name":"Bash","tool_input":{"command":"git push -f"}}'
P3='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"$(cat <<'"'"'EOF'"'"'\nundo git reset --hard\nEOF\n)\""}}'
P4='{"tool_name":"Bash","tool_input":{"command":"cat >> notes.md <<'"'"'EOF'"'"'\n- never git reset --hard\nEOF"}}'
P5='{"tool_name":"Bash","tool_input":{"command":"git stash drop"}}'
for d in $LIST; do
    rel=${d#$BASE/}
    case "$APPROVED" in *" $rel "*) ;; *) echo "  SKIP (not on the approved list — ask the user): $rel"; continue ;; esac
    if [ "$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)" != "$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ] \
       && ! git -C "$d" symbolic-ref -q HEAD >/dev/null 2>&1; then
        echo "  SKIP (detached linked worktree): $rel"; continue
    fi
    LOG="$d/.claude/.upgrade-$WANT.log"
    before=$(cat "$d/.claude/.cc-discipline-version" 2>/dev/null | tr -d '\r\n'); [ -n "$before" ] || before=none
    (cd "$d" && npx -y --package="$TGZ" cc-discipline upgrade > "$LOG" 2>&1 </dev/null); rc=$?
    after=$(cat "$d/.claude/.cc-discipline-version" 2>/dev/null | tr -d '\r\n')
    G="$d/.claude/hooks/git-guard.sh"
    fn="$(t "$G" "$P1" 2)/$(t "$G" "$P2" 2)/$(t "$G" "$P3" 0)/$(t "$G" "$P4" 0)/$(t "$G" "$P5" 2)"
    regs=$(grep -o 'git-guard\.sh' "$d/.claude/settings.json" 2>/dev/null | wc -l | tr -d ' ')
    printf '  %-7s -> %-7s rc=%s  guard=%s  regs=%s  %s\n' "$before" "${after:-?}" "$rc" "$fn" "$regs" "$rel"
    sed 's/\x1b\[[0-9;]*m//g' "$LOG" | awk '/Needs your attention/ { on = 1 } on && /^$/ { exit } on' | sed 's/^/      │ /'
    [ "$rc" = 0 ] && [ "$after" = "$WANT" ] && rm -f "$LOG"
done
for a in $APPROVED; do
    printf '%s\n' "$LIST" | grep -qx "$BASE/$a" || echo "  MISSING (approved but not found): $a"
done
