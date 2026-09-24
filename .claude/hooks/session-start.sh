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

# Project state, read from two files, each only if present:
#   docs/progress.md — its status section. This used to be `tail -20`, which
#     injected the end of whichever section happened to be last and never the
#     status. A progress.md without a status heading still falls back to the tail.
#   docs/todo.md — the "## Now" section in full, and a count of "## Later" items.
#     Later items are counted, not listed: the list can grow long, and /self-check
#     is where their revisit conditions get checked.
# Both files are hand-edited, so CRs are stripped (a CRLF checkout would leave one
# on every line) and HTML comments are dropped. Portable awk only — this has to
# behave the same under macOS's BSD awk. Fails silent: a missing or reshaped file
# injects nothing rather than something misleading.
#
# What 2.14.0's field reports taught (2026-09-24), all handled below:
#   - Headings carry suffixes and other languages: "## Current Status (2026-05-26)",
#     "## 当前态(2026-09-05)— …". A heading matches when it STARTS with a known
#     name and the next character is not a letter or digit.
#   - A "## " line inside a code fence is content, not a heading.
#   - A status section can be months old while newer entries pile up below it.
#     Its date (from the heading or a "Last updated" line) is compared with the
#     newest dated heading in the file and with today, and a stale one is flagged.
#   - Some projects keep a long status on purpose. `<!-- cc-discipline:
#     status-lines=N -->` anywhere in progress.md raises the default of 15.
#   - Indented sub-items under Later are not items, and "each has a revisit
#     condition" is only said when every item actually has one.
# Comment state is tracked on every line, before any heading test, so a heading
# written inside <!-- ... --> neither opens nor closes a section.
# Every fork costs tens of milliseconds on Windows Git Bash, so awk strips the
# CRs itself and its output is parsed with bash builtins: this runs at the
# start of every session.

# Shared awk: comment and fence tracking, and heading matching by prefix.
AWK_LIB='
function heading_is(t, name,    p, nx) {   # t starts with "## <name>" + a non-word char or nothing
    p = "## " name
    if (tolower(substr(t, 1, length(p))) != tolower(p)) return 0
    nx = substr(t, length(p) + 1, 1)
    return (nx == "" || nx !~ /[A-Za-z0-9_]/)
}
function date_in(s) {                         # first YYYY-MM-DD in s, or ""
    if (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) return substr(s, RSTART, RLENGTH)
    return ""
}
# skip() consumes comment and fence lines; returns 1 when the caller should
# treat the line as plain content (inside a fence), 2 when it should skip it.
function skip() {
    if (inc) { if (/-->/) inc = 0; return 2 }
    if (/^[ \t]*(```|~~~)/) { infence = !infence; return 1 }
    if (infence) return 1
    if (/<!--/) { if (!/-->/) inc = 1; return 2 }
    return 0
}'

STATUS=""; STATUS_NOTE=""
if [ -f "docs/progress.md" ]; then
    # One pass. Emits "@key=value" lines, then the capped body as "|line".
    PROGRESS=$(awk "$AWK_LIB"'
        BEGIN { lines = 15 }
        { sub(/\r$/, "") }
        /<!--[ \t]*cc-discipline:[ \t]*status-lines=/ {
            v = $0; sub(/.*status-lines=/, "", v); sub(/[^0-9].*/, "", v)
            if (v != "" && v + 0 >= 1 && v + 0 <= 400) lines = v + 0
        }
        { k = skip() }
        k == 2 { next }
        k == 1 { if (on && NF) body[++nb] = $0; next }
        { t = $0; sub(/[ \t]+$/, "", t) }
        /^#+ / { d = date_in(t); if (d > newest) newest = d }
        /^## / {
            if (on) { on = 0; done = 1 }
            else if (!done && (heading_is(t, "Current Status") || heading_is(t, "当前态") || heading_is(t, "当前状态"))) {
                on = 1; found = 1; sdate = date_in(t); next
            }
        }
        on && /^-+[ \t]*$/ { next }
        on && NF {
            body[++nb] = $0
            if (sdate == "" && tolower($0) ~ /last updated|updated:|最后更新|更新于/) sdate = date_in($0)
        }
        END {
            print "@found=" (found ? 1 : 0); print "@sdate=" sdate; print "@newest=" newest
            print "@more=" (nb > lines ? nb - lines : 0)
            for (i = 1; i <= nb && i <= lines; i++) print "|" body[i]
        }' docs/progress.md 2>/dev/null)
    FOUND=0; SDATE=""; NEWEST=""; MORE=0
    while IFS= read -r L; do
        case "$L" in
            @found=*)  FOUND=${L#@found=} ;;
            @sdate=*)  SDATE=${L#@sdate=} ;;
            @newest=*) NEWEST=${L#@newest=} ;;
            @more=*)   MORE=${L#@more=} ;;
            \|*)       STATUS="${STATUS:+$STATUS
}${L#|}" ;;
        esac
    done <<< "$PROGRESS"
    if [ "$FOUND" = 1 ]; then
        if [ -n "$STATUS" ] && [ "${MORE:-0}" -gt 0 ]; then
            STATUS="$STATUS
... and $MORE more lines under Current Status in docs/progress.md."
        fi
        # Staleness. ISO dates compare as strings; the calendar age is approximate
        # (31-day months), which is enough for "more than two weeks".
        if [ -n "$STATUS" ] && [ -n "$SDATE" ]; then
            if [ -n "$NEWEST" ] && [[ "$NEWEST" > "$SDATE" ]]; then
                STATUS_NOTE="Note: this status was last updated $SDATE, but progress.md has entries dated up to $NEWEST — it may be stale."
            else
                TODAY="${CC_DISCIPLINE_TODAY:-$(date +%Y-%m-%d)}"   # overridable for the test matrix
                AGE=$(( (10#${TODAY:0:4}*372 + 10#${TODAY:5:2}*31 + 10#${TODAY:8:2}) \
                      - (10#${SDATE:0:4}*372 + 10#${SDATE:5:2}*31 + 10#${SDATE:8:2}) ))
                [ "$AGE" -gt 14 ] && \
                    STATUS_NOTE="Note: this status was last updated $SDATE, about $AGE days ago — it may be stale."
            fi
        fi
    else
        STATUS=$(sed 's/\r$//' docs/progress.md | tail -20)
    fi
fi

NOW=""; NOW_MORE=0; LATER=0; NOCOND=0
if [ -f "docs/todo.md" ]; then
    # One pass: the Now body (capped at 20), and Later's top-level items. An open
    # item is a top-level bullet that isn't ticked ("- [ ] x" or "- x", not
    # "- [x] x"); indented lines belong to the item above them.
    TODO=$(awk "$AWK_LIB"'
        function close_item() { if (item && !cond) nocond++; item = 0 }
        { sub(/\r$/, "") }
        { k = skip() }
        k == 2 { next }
        k == 1 { if (sec == "now" && NF) now[++nn] = $0; next }
        { t = $0; sub(/[ \t]+$/, "", t) }
        /^## / {
            close_item()
            sec = heading_is(t, "Now") ? "now" : (heading_is(t, "Later") ? "later" : "")
            next
        }
        sec == "now" && /^-+[ \t]*$/ { next }
        sec == "now" && NF { now[++nn] = $0; next }
        sec == "later" && /^[-*] / {
            close_item()
            if ($0 ~ /^[-*] \[[xX]\]/) next
            item = 1; later++; cond = (tolower($0) ~ /revisit|回看|再看/)
            next
        }
        sec == "later" && item && tolower($0) ~ /revisit|回看|再看/ { cond = 1 }
        END {
            close_item()
            print "@later=" later + 0; print "@nocond=" nocond + 0; print "@nowmore=" (nn > 20 ? nn - 20 : 0)
            for (i = 1; i <= nn && i <= 20; i++) print "|" now[i]
        }' docs/todo.md 2>/dev/null)
    while IFS= read -r L; do
        case "$L" in
            @later=*)   LATER=${L#@later=} ;;
            @nocond=*)  NOCOND=${L#@nocond=} ;;
            @nowmore=*) NOW_MORE=${L#@nowmore=} ;;
            \|*)        NOW="${NOW:+$NOW
}${L#|}" ;;
        esac
    done <<< "$TODO"
    case "$NOW_MORE$LATER$NOCOND" in *[!0-9]*|'') NOW_MORE=0; LATER=0; NOCOND=0 ;; esac
fi

cat <<'HEADER'
[cc-discipline] Session initialized.
HEADER

if [ -n "$STATUS" ]; then
    printf '\nProject state (from docs/progress.md):\n%s\n' "$STATUS"
    [ -n "$STATUS_NOTE" ] && printf '%s\n' "$STATUS_NOTE"
fi
if [ -n "$NOW" ] || [ "$LATER" -gt 0 ]; then
    printf '\nOpen work (from docs/todo.md):\n'
    [ -n "$NOW" ] && printf 'Now:\n%s\n' "$NOW"
    [ "$NOW_MORE" -gt 0 ] && printf '... and %s more under Now.\n' "$NOW_MORE"
    if [ "$LATER" -gt 0 ]; then
        if [ "$NOCOND" -gt 0 ]; then
            printf 'Later: %s item(s); %s without a revisit condition — add one, or move the item to Now.\n' "$LATER" "$NOCOND"
        else
            printf 'Later: %s item(s), each with a revisit condition.\n' "$LATER"
        fi
    fi
fi
if [ -n "$STATUS" ] || [ -n "$NOW" ] || [ "$LATER" -gt 0 ]; then
    printf "\nVerify project status by reading files or asking — don't assume beyond what is stated above.\n"
fi

# Only the skill pointer is injected here. The four rule restatements that used
# to follow it (pre-edit checks, 3-failure rule, confirm-before-implementing,
# verify project state) were removed 2026-07-30 as duplicates of rules injected
# every session (00-core §4, 05, 07 §4a; the pre-edit checks lived in 02, which was
# itself retired 2026-09-23 for duplicating other rules). Skills are the one thing
# rules don't announce.
cat <<'EOF'

/self-check is available for periodic monitoring — for long tasks: /loop 10m /self-check
EOF

exit 0
