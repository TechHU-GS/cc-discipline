#!/bin/bash
# Behaviour matrix for session-start.sh — what it injects from docs/progress.md
# and docs/todo.md.
#
# Why this exists: the hook used to inject `tail -20 docs/progress.md`, which is
# the end of whichever section is last and never the status or the open work.
# It now parses sections out of files users edit by hand, so it has to survive
# CRLF line endings, heading case and trailing spaces, HTML comments, ticked
# items, a long Now list, and files that don't follow the template at all.
# Run after ANY change to session-start.sh.
#
# Usage: bash tests/session-start-matrix.sh [path-to-session-start.sh]
#        defaults to the templates/ copy.

HOOK="${1:-templates/.claude/hooks/session-start.sh}"
[ -f "$HOOK" ] || { echo "not found: $HOOK"; exit 1; }
HOOK=$(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0

# run <case-dir> → hook output in $OUT, exit code in $RC
run() {
    # "Today" is pinned so staleness notes don't depend on when the matrix runs.
    OUT=$(cd "$1" && printf '{"session_id":"matrix"}' | CC_DISCIPLINE_TODAY=2026-09-24 bash "$HOOK" 2>&1); RC=$?
}
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has()  { case "$OUT" in *"$2"*) ok "$1";; *) bad "$1 — missing: $2";; esac; }
lacks(){ case "$OUT" in *"$2"*) bad "$1 — unexpected: $2";; *) ok "$1";; esac; }
crlf() { awk '{ printf "%s\r\n", $0 }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

newcase() { D="$WORK/$1"; mkdir -p "$D/docs"; }

STATUS_DOC='# Progress & Decision Log

## Current Status

- **In progress**: wiring the export job
- **Last updated**: 2026-09-23

---

## Milestones

### 2026-09-20 — first milestone
Old detail that must not be injected.

## Rule Ledger

| date | kind | note |
| 2026-09-21 | SAVE | ledger line that must not be injected |'

TODO_DOC='# TODO

## Now

- [ ] Finish the export job
- [ ] Add the retry test

## Later

<!-- example, must not count:
- [ ] commented example — revisit: never
-->
- [ ] Rotate the token — revisit: before the next publish
- Upgrade the runner — revisit: when CI moves
- [x] Ticked item that should have been deleted'

echo "--- no docs at all ---"
newcase none; run "$D"
has   "exits 0 with header"            "[cc-discipline] Session initialized."
lacks "no project-state block"         "Project state"
lacks "no open-work block"             "Open work"
[ "$RC" -eq 0 ] && ok "exit code 0" || bad "exit code $RC"

echo "--- fresh install (shipped templates) ---"
newcase fresh
# Always the shipped templates, whichever hook copy is under test. Deriving the
# path from the hook's location picked up this repo's own docs/ when the
# installed copy (.claude/hooks/) was tested, and failed three cases.
TPL="$(cd "$(dirname "$0")/.." && pwd)/templates/docs"
cp "$TPL/progress.md" "$D/docs/progress.md"
cp "$TPL/todo.md" "$D/docs/todo.md"
run "$D"
has   "status section injected"        "**In progress**"
lacks "template Later examples not counted" "Later:"
lacks "empty Now not announced"        "Now:"
lacks "Rule Ledger not injected"       "Rule Ledger"

echo "--- status + todo, LF ---"
newcase lf; printf '%s\n' "$STATUS_DOC" > "$D/docs/progress.md"; printf '%s\n' "$TODO_DOC" > "$D/docs/todo.md"
run "$D"
has   "current status injected"        "wiring the export job"
lacks "milestone body not injected"    "Old detail"
lacks "ledger not injected"            "ledger line"
has   "Now item 1"                     "Finish the export job"
has   "Now item 2"                     "Add the retry test"
has   "Later counts 2 open (ticked and commented excluded)" "Later: 2 item(s)"
LF_OUT="$OUT"

echo "--- same files, CRLF ---"
newcase crlf; printf '%s\n' "$STATUS_DOC" > "$D/docs/progress.md"; printf '%s\n' "$TODO_DOC" > "$D/docs/todo.md"
crlf "$D/docs/progress.md"; crlf "$D/docs/todo.md"
run "$D"
case "$OUT" in *$'\r'*) bad "no CR leaks into the output";; *) ok "no CR leaks into the output";; esac
[ "$OUT" = "$LF_OUT" ] && ok "CRLF output identical to LF output" || bad "CRLF output differs from LF output"

echo "--- progress.md without a Current Status heading ---"
newcase nostatus
printf '%s\n' "# My own log" "" "Some line" "Last line of a hand-rolled log" > "$D/docs/progress.md"
run "$D"
has   "falls back to the tail"         "Last line of a hand-rolled log"

echo "--- heading case and trailing spaces ---"
newcase headings
printf '%s\n' "## Current status   " "- **In progress**: casing test" > "$D/docs/progress.md"
printf '%s\n' "## now  " "- [ ] lower-case heading item" "## LATER" "- [ ] upper-case heading item — revisit: soon" > "$D/docs/todo.md"
run "$D"
has   "status heading matched"         "casing test"
has   "now heading matched"            "lower-case heading item"
has   "later heading matched"          "Later: 1 item(s)"

echo "--- a following section ends Now ---"
newcase bounded
printf '%s\n' "## Now" "- [ ] inside Now" "## Notes" "- [ ] a note, not a task" > "$D/docs/todo.md"
run "$D"
has   "Now content present"            "inside Now"
lacks "next section excluded"          "a note, not a task"

echo "--- long Now list is capped ---"
newcase long
{ echo "## Now"; for i in $(seq 1 25); do echo "- [ ] task $i"; done; } > "$D/docs/todo.md"
run "$D"
has   "item 20 shown"                  "task 20"
lacks "item 21 not shown"              "task 21"
has   "overflow announced"             "... and 5 more under Now."

echo "--- Current Status heading present but empty ---"
newcase emptystatus
printf '%s\n' "## Current Status" "" "## Milestones" "- unrelated tail line from an old milestone" > "$D/docs/progress.md"
run "$D"
lacks "no tail fallback for an empty section"   "unrelated tail line"
lacks "no project-state block for an empty section" "Project state"

echo "--- long Current Status is capped with a note ---"
newcase longstatus
{ echo "## Current Status"; for i in $(seq 1 18); do echo "- status line $i"; done; } > "$D/docs/progress.md"
run "$D"
has   "status line 15 shown"           "status line 15"
lacks "status line 16 not shown"       "status line 16"
has   "status overflow announced"      "3 more lines under Current Status"

echo "--- headings inside HTML comments are ignored ---"
newcase comments
printf '%s\n' "<!--" "## Now" "- [ ] commented-out fake item" "-->" "## Now" "- [ ] real item" \
  "<!--" "## example heading inside a comment" "-->" "- [ ] item after the comment" > "$D/docs/todo.md"
run "$D"
has   "real Now item shown"            "real item"
has   "item after an in-section comment kept" "item after the comment"
lacks "commented-out section ignored"  "commented-out fake item"

# ── 2.14.0 field reports (HUB_Rev1_FW, ziiqii-geosense, techhu-devices) ──
echo "--- status headings with a suffix, or in Chinese ---"
newcase suffix;  printf '%s\n' "## Current Status (2026-09-20)" "- suffixed heading body" > "$D/docs/progress.md"; run "$D"
has   "suffix after Current Status"    "suffixed heading body"
newcase dangtai; printf '%s\n' "## 当前态(2026-09-20)— 这一段只替换不追加" "- 当前态正文" "## 里程碑" "- 不该注入" > "$D/docs/progress.md"; run "$D"
has   "当前态 with a suffix"           "当前态正文"
lacks "当前态 ends at the next heading" "不该注入"
newcase dqzt;    printf '%s\n' "## 当前状态" "- 当前状态正文" > "$D/docs/progress.md"; run "$D"
has   "当前状态"                        "当前状态正文"
newcase statuses
{ printf '%s\n' "## Current Statuses" "- not a status section, must not be injected"; for i in $(seq 1 25); do echo "filler line $i"; done; } > "$D/docs/progress.md"; run "$D"
lacks "a longer word is not a match"   "not a status section"

echo "--- a code fence inside Current Status ---"
newcase fence
printf '%s\n' "## Current Status" "- a before fence" '```bash' "## not a heading, inside a code block" '```' "- b after fence" "## Milestones" "- milestone line" > "$D/docs/progress.md"
run "$D"
has   "text after the fence kept"      "b after fence"
has   "fenced line kept as content"    "not a heading, inside a code block"
lacks "section still ends at the next real heading" "milestone line"

echo "--- Later: sub-items and revisit conditions ---"
newcase subitems
printf '%s\n' "## Later" "- [ ] parent item — revisit: later" "    - sub a" "    - sub b" > "$D/docs/todo.md"; run "$D"
has   "indented sub-items not counted" "Later: 1 item(s)"
has   "all items have a condition"     "each with a revisit condition"
newcase nocond
printf '%s\n' "## Later" "- [ ] has one — revisit: before release" "- [ ] has none" "- [ ] wrapped item" "  continued here — revisit: next week" > "$D/docs/todo.md"; run "$D"
has   "three open items"               "Later: 3 item(s)"
has   "the item without a condition is reported" "1 without a revisit condition"
lacks "no blanket claim when one lacks a condition" "each with a revisit condition"

echo "--- a stale Current Status is flagged ---"
newcase stale_newer
printf '%s\n' "## Current Status" "- **Last updated**: 2026-05-18" "- old state" "## Milestones" "### 2026-09-23 — newest entry" "- m" > "$D/docs/progress.md"; run "$D"
has   "stale: newer entry exists"      "may be stale"
has   "names the newer date"           "2026-09-23"
newcase stale_today
printf '%s\n' "## Current Status" "- **Last updated**: 2026-05-18" "- old state" > "$D/docs/progress.md"; run "$D"
has   "stale: old by the calendar"     "may be stale"
newcase fresh_status
printf '%s\n' "## Current Status" "- **Last updated**: 2026-09-23" "- current state" "### 2026-09-20 — older entry" > "$D/docs/progress.md"; run "$D"
lacks "fresh status not flagged"       "may be stale"
newcase stale_heading
printf '%s\n' "## 当前态(2026-09-05)" "- 状态" "## 2026-09-20 · 新条目" "- x" > "$D/docs/progress.md"; run "$D"
has   "date taken from the heading"    "2026-09-05"
has   "heading-dated status flagged"   "may be stale"

echo "--- status length set per project ---"
newcase lines30
{ echo "<!-- cc-discipline: status-lines=30 -->"; echo "## Current Status"; for i in $(seq 1 40); do echo "- status line $i"; done; } > "$D/docs/progress.md"; run "$D"
has   "line 30 shown"                  "status line 30"
lacks "line 31 not shown"              "status line 31"
has   "overflow counted from 30"       "10 more lines under Current Status"
lacks "the marker itself is not injected" "cc-discipline: status-lines"
newcase badmarker
{ echo "<!-- cc-discipline: status-lines=0 -->"; echo "## Current Status"; for i in $(seq 1 18); do echo "- status line $i"; done; } > "$D/docs/progress.md"; run "$D"
lacks "an out-of-range marker falls back to 15" "status line 16"

echo
echo "通过 $PASS / 失败 $FAIL"
[ "$FAIL" -eq 0 ]
