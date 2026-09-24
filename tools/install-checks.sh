#!/bin/bash
# Install-level checks for this working tree: the modified-hook report, the
# hooks manifest, and the .new reminders in upgrade, doctor and status.
# Run after touching init.sh, lib/doctor.sh, lib/status.sh or lib/hook-hashes.
#
# Usage:  bash tools/install-checks.sh <repo dir> <older release tarball>
#   e.g.  bash tools/install-checks.sh /e/Code/cc-discipline <path>/cc-discipline-2.14.0.tgz
#   The older tarball comes from `npm pack` of an earlier commit, or from the
#   registry (npm pack cc-discipline@<version>). Case E also installs
#   cc-discipline@2.13.6 from the registry, which needs network access.
# Expect: "passed 13 / failed 0" on MS-01, mac-mini and techhu-7940 Git Bash.
REPO="${1:?usage: install-checks.sh <repo dir> <older tarball>}"; OLD="${2:?older tarball}"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }
new_project() { P=$(mktemp -d); cd "$P" || exit 1; git init -q; }
up() { CC_DISCIPLINE_PKG_DIR="$REPO" node "$REPO/bin/cli.js" upgrade </dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }

echo "-- A: an unmodified install of the older release"
new_project; npx -y --package="$OLD" cc-discipline init --auto --stack 3 >/dev/null 2>&1 </dev/null
OUT=$(up)
case "$OUT" in *"REPLACED"*) bad "no hook reported as modified";; *) ok "no hook reported as modified";; esac
[ "$(grep -c '\.sh sha256:\|\.sh md5:\|\.sh cksum:' .claude/.cc-discipline-hooks.manifest 2>/dev/null)" = 7 ] && ok "hooks manifest has 7 entries" || bad "hooks manifest has 7 entries"

echo "-- B: session-start edited locally (HUB_Rev1_FW's case)"
echo "# local tweak" >> .claude/hooks/session-start.sh
OUT=$(up)
case "$OUT" in *"REPLACED: session-start.sh"*) ok "session-start reported as replaced";; *) bad "session-start reported as replaced";; esac
case "$OUT" in *".backup-"*"/hooks/"*) ok "backup path given";; *) bad "backup path given";; esac
case "$OUT" in *"REPLACED:"*"git-guard.sh"*) bad "only the edited hook is named";; *) ok "only the edited hook is named";; esac
cmp -s .claude/hooks/session-start.sh "$REPO/templates/.claude/hooks/session-start.sh" && ok "hook now matches the template" || bad "hook now matches the template"
B=$(ls -d .claude/.backup-* | tail -1); grep -q '# local tweak' "$B/hooks/session-start.sh" && ok "the edit survives in the backup" || bad "the edit survives in the backup"

echo "-- C: the next upgrade, with a manifest now"
OUT=$(up)
case "$OUT" in *"REPLACED"*) bad "nothing reported the second time";; *) ok "nothing reported the second time";; esac

echo "-- D: a hook checked out with CRLF (core.autocrlf)"
awk '{ printf "%s\r\n", $0 }' .claude/hooks/git-guard.sh > g.tmp && mv g.tmp .claude/hooks/git-guard.sh
OUT=$(up)
case "$OUT" in *"REPLACED"*) bad "CRLF is not a local change";; *) ok "CRLF is not a local change";; esac

echo "-- E: an unmodified 2.13.6 install from the registry (no hooks manifest)"
new_project; npx -y cc-discipline@2.13.6 init --auto --stack 3 >/dev/null 2>&1 </dev/null
OUT=$(up)
case "$OUT" in *"REPLACED"*) bad "2.13.6 hooks recognised as shipped";; *) ok "2.13.6 hooks recognised as shipped";; esac

echo "-- F: a skill template waiting as .new"
echo "local line" >> .claude/skills/self-check/SKILL.md
OUT=$(up)
case "$OUT" in *"Needs your attention"*"self-check"*) ok "upgrade lists the kept skill at the end";; *) bad "upgrade lists the kept skill at the end";; esac
D=$(CC_DISCIPLINE_PKG_DIR="$REPO" node "$REPO/bin/cli.js" doctor </dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case "$D" in *"waiting to be merged: self-check"*) ok "doctor lists the pending .new";; *) bad "doctor lists the pending .new";; esac
S=$(CC_DISCIPLINE_PKG_DIR="$REPO" node "$REPO/bin/cli.js" status </dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case "$S" in *"waiting to be merged: /self-check"*) ok "status lists the pending .new";; *) bad "status lists the pending .new";; esac

cd /; echo; echo "passed $PASS / failed $FAIL"
[ "$FAIL" -eq 0 ]
