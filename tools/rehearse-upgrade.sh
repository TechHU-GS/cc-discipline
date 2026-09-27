#!/bin/bash
# Rehearse an upgrade in a throwaway project before rolling it out: install the
# release the fleet runs, upgrade it from the new tarball, then check the
# result the way the rollout will.
#
# Usage:  bash tools/rehearse-upgrade.sh <old package> <new tarball>
#   <old package> is a tarball path or a registry spec such as cc-discipline@2.13.6.
#   Tarball paths go through `npx --package=`: a bare Windows path given to npx
#   exits 0 and does nothing.
#   Remote:  ssh techhu@100.64.0.8 'bash -ls -- /tmp/old.tgz /tmp/new.tgz' < tools/rehearse-upgrade.sh
#
# Expect: the new version, a 7-entry hooks manifest, no attention block, five
# guard lines "ok", a staleness note, and doctor rc=0.
OLD="${1:?usage: rehearse-upgrade.sh <old package> <new tarball>}"; NEW="${2:?new tarball}"
P=$(mktemp -d); cd "$P" || exit 1; git init -q
# --prefer-online: npm's local metadata cache lags a fresh publish, and a version
# published an hour earlier failed with ETARGET on techhu-7940 (2026-09-28).
npx -y --prefer-online --package="$OLD" cc-discipline init --auto --stack 3 > init.log 2>&1 </dev/null
echo "before: $(cat .claude/.cc-discipline-version 2>/dev/null)"
# Without the old release in place this would rehearse a fresh install, not an
# upgrade. Checked by the marker, since the oldest releases write no version file.
[ -f .claude/hooks/streak-breaker.sh ] || { echo "FAIL: $OLD did not install:"; tail -5 init.log; cd /; rm -rf "$P"; exit 1; }
npx -y --package="$NEW" cc-discipline upgrade > up.log 2>&1 </dev/null; echo "upgrade rc=$?"
echo "after:  $(cat .claude/.cc-discipline-version 2>/dev/null) · hooks manifest: $(grep -c . .claude/.cc-discipline-hooks.manifest 2>/dev/null) entries · attention block: $(grep -c 'Needs your attention' up.log)"
G=.claude/hooks/git-guard.sh
t() { printf '%s' "$2" | bash "$G" >/dev/null 2>&1; r=$?; [ "$r" = "$1" ] && echo "  ok   rc=$r  $3" || echo "  FAIL rc=$r want $1  $3"; }
t 2 '{"tool_name":"Bash","tool_input":{"command":"git -C repo reset --hard"}}' 'git -C repo reset --hard'
t 2 '{"tool_name":"Bash","tool_input":{"command":"git push -f"}}'              'git push -f (no refspec)'
t 0 '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"$(cat <<'"'"'EOF'"'"'\nundo git reset --hard\nEOF\n)\""}}' 'heredoc commit message'
t 0 '{"tool_name":"Bash","tool_input":{"command":"cat >> notes.md <<'"'"'EOF'"'"'\n- never git reset --hard\nEOF"}}' 'note appended with a cat heredoc'
t 2 '{"tool_name":"Bash","tool_input":{"command":"git stash drop"}}'           'git stash drop'
printf '%s\n' '## Current Status (2026-09-01)' '- a status line' '## 2026-09-20 · newer entry' > docs/progress.md
echo '{"session_id":"t"}' | bash .claude/hooks/session-start.sh | grep -E 'a status line|may be stale' | sed 's/^/  session-start: /'
echo "doctor rc=$(npx -y --package="$NEW" cc-discipline doctor >/dev/null 2>&1 </dev/null; echo $?)"
cd /; rm -rf "$P"
