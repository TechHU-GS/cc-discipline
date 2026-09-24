#!/bin/bash
# cc-discipline: Guard against destructive git commands
# PreToolUse on Bash — blocks git checkout/restore/reset --hard/clean -f,
# branch -D and force-pushes to main/master until the user confirms.
#
# Failure direction: LOUD. A spurious confirmation prompt costs one turn; a
# miss costs the user's uncommitted work.
#
# How it decides (redesigned 2026-09-23 after a review found 14 destructive
# forms that the old one-regex-per-rule version let through):
#   1. Read the payload exactly: top-level tool_name, and command directly
#      inside tool_input — the paths jq would read, without needing jq.
#   2. Lift every $(...) and `...` out into its own work item: substitutions
#      execute even inside a quoted -m message.
#   3. Tokenize with bash quoting rules and split into single commands at
#      ; && || | & ( ) and newlines. Quoted text is also queued as its own work
#      item (bash -c "...", eval "...", ssh host "..."), except the argument of
#      -m/--message/-F/--file, which is data. Heredoc bodies are queued as code:
#      a heredoc fed to bash executes (see CLAUDE.md Known Pitfalls).
#   4. For each git invocation, skip global options (-C, -c, --git-dir, ...),
#      find the subcommand and judge its flag SET — order and spelling
#      (-df, -d -f, --delete --force) no longer matter.
# The awk program prints exactly one verdict line. If it prints anything else
# — awk missing, a crash, a command too tangled to follow — the wrapper falls
# back to a coarse text check and blocks when it sees git plus a guarded
# subcommand. A crash must never become exit 1: Claude Code treats any exit
# other than 2 as a non-blocking error, i.e. the command runs. Payloads over
# 64 KB skip the parser and go straight to that coarse check (see below).
#
# Out of scope by design: deliberate obfuscation ($G reset, git aliases). This
# guards against a fast, careless agent, not an adversary.
#
# Test: bash tests/git-guard-matrix.sh [path-to-this-file]

IFS= read -r -d '' INPUT

IFS= read -r -d '' PROG <<'AWK'
function has_git(s) { return index(tolower(s), "git") > 0 }

function enqueue(s) {
    if (!has_git(s)) return        # no rule can fire without a git word
    if (QN >= QMAX) { OVERFLOW = 1; return }
    QN++; Q[QN] = s
}

function block(reason, hint) {
    if (VERDICT == "") VERDICT = "BLOCK\t" reason "\t" hint
}

# ── 1. Payload ────────────────────────────────────────────────────────────
# A small JSON walk that tracks depth and the key each value belongs to, so a
# "command" key anywhere else can never stand in for tool_input.command.
function json_string(s, i, n,    out, c, e, start) {
    out = ""; i++
    while (i <= n) {
        start = i
        while (i <= n) { c = substr(s, i, 1); if (c == "\\" || c == "\"") break; i++ }
        out = out substr(s, start, i - start)
        if (i > n) break
        if (c == "\"") { JEND = i; return out }
        e = substr(s, i + 1, 1)
        if (e == "n") out = out "\n"
        else if (e == "t") out = out "\t"
        else if (e == "r") out = out "\r"
        else if (e == "b" || e == "f") out = out " "
        else if (e == "u") out = out "\\u"          # \uXXXX stays literal
        else out = out e                            # \" \\ \/
        i += 2
    }
    JEND = n; return out
}

function parse_payload(s,    n, i, c, d, str) {
    n = length(s); d = 0; i = 1
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == "{" || c == "[") {
            d++; KIND[d] = c; CURK[d] = ""; WANTK[d] = (c == "{")
            PKEY[d] = (d > 1 && KIND[d - 1] == "{") ? CURK[d - 1] : ""
            i++; continue
        }
        if (c == "}" || c == "]") { d--; i++; continue }
        if (c == ",") { if (d > 0 && KIND[d] == "{") WANTK[d] = 1; i++; continue }
        if (c == ":") { if (d > 0) WANTK[d] = 0; i++; continue }
        if (c == "\"") {
            str = json_string(s, i, n); i = JEND + 1
            if (d > 0 && KIND[d] == "{" && WANTK[d]) { CURK[d] = str; continue }
            if (d == 1 && CURK[1] == "tool_name" && !HAVETOOL) { TOOL = str; HAVETOOL = 1 }
            else if (d == 2 && KIND[1] == "{" && KIND[2] == "{" && PKEY[2] == "tool_input" \
                     && CURK[2] == "command" && !HAVECMD) { CMD = str; HAVECMD = 1 }
            continue
        }
        i++
    }
}

# ── 2. Command substitutions ──────────────────────────────────────────────
# Quoting is ignored here on purpose, so a ")" inside a quoted string can end
# a substitution early. Every character still ends up either in the returned
# string or in a queued item — but the leftover can land inside a message
# argument, which is not scanned. queue_lifted() covers that case. The one
# thing dropped on purpose is the commit-message heredoc below.
function lift_substitutions(s,    n, i, c, out, j, depth, st, w, mp) {
    n = length(s); out = ""; i = 1; st = 1         # s[st..i-1] is pending, not yet in out
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == "$" && substr(s, i + 1, 1) == "(") {
            out = out substr(s, st, i - st)
            # Only the tail can decide message position. Matching all of out
            # on every "$(" made long commands quadratic.
            if (length(out) > 64) { w = substr(out, length(out) - 63); mp = (w ~ MSGTAIL) }
            else mp = (out ~ MSGPOS)
            if (mp && (j = message_heredoc_end(s, i + 2, n)) > 0) {
                out = out "SUBST"; i = j + 1; st = i; continue
            }
            depth = 1; j = i + 2
            while (j <= n) {
                c = substr(s, j, 1)
                if (c == "(") depth++
                else if (c == ")") { depth--; if (depth == 0) break }
                j++
            }
            enqueue(substr(s, i + 2, j - i - 2))
            out = out "SUBST"; i = j + 1; st = i; continue
        }
        if (c == "`") {
            j = i + 1
            while (j <= n && substr(s, j, 1) != "`") j++
            if (j <= n) {
                out = out substr(s, st, i - st)
                enqueue(substr(s, i + 1, j - i - 1)); out = out "SUBST"; i = j + 1; st = i; continue
            }
        }
        i++
    }
    return out substr(s, st)
}

# Index of the next newline at or after j, or 0. A scan rather than
# index(substr(s, j), "\n"), which copies the rest of s on every line and made
# long heredocs quadratic: 9 s for a 200 KB command under BSD awk.
function eol(s, j, n) {
    while (j <= n && substr(s, j, 1) != "\n") j++
    return (j <= n) ? j : 0
}

# -m "$(cat <<'EOF' ... EOF)" is how Claude Code writes commit messages. With a
# QUOTED delimiter the body is not expanded, so it is data, never code. Returns
# the index of the closing ")" when the substitution is exactly that form —
# only blanks after the terminator line — and 0 otherwise. The terminator is
# found before any parenthesis is counted, so "1)" in a message is harmless.
function message_heredoc_end(s, j, n,    dash, q, k, delim, line, e) {
    while (substr(s, j, 1) ~ /[ \t]/) j++
    if (substr(s, j, 3) != "cat") return 0
    j += 3
    if (substr(s, j, 1) !~ /[ \t]/) return 0
    while (substr(s, j, 1) ~ /[ \t]/) j++
    if (substr(s, j, 2) != "<<") return 0
    j += 2; dash = 0
    if (substr(s, j, 1) == "-") { dash = 1; j++ }
    while (substr(s, j, 1) ~ /[ \t]/) j++
    q = substr(s, j, 1)
    if (q == "'" || q == "\"") {
        k = index(substr(s, j + 1), q); if (k == 0) return 0
        delim = substr(s, j + 1, k - 1); j = j + k + 1
    } else if (q == "\\") {
        j++; k = j
        while (substr(s, k, 1) ~ /[A-Za-z0-9_]/) k++
        delim = substr(s, j, k - j); j = k
    } else return 0                                 # unquoted: body expands
    if (delim !~ /^[A-Za-z0-9_]+$/) return 0
    while (substr(s, j, 1) ~ /[ \t\r]/) j++
    if (substr(s, j, 1) != "\n") return 0           # e.g. cat <<'X' | sh
    j++
    while (j <= n) {
        e = eol(s, j, n)
        line = (e > 0) ? substr(s, j, e - j) : substr(s, j)
        sub(/\r$/, "", line)
        if (dash) sub(/^\t+/, "", line)
        if (line == delim) {
            j = (e > 0) ? e + 1 : n + 1
            while (j <= n && substr(s, j, 1) ~ /[ \t\r\n]/) j++
            return (substr(s, j, 1) == ")") ? j : 0
        }
        if (e == 0) return 0
        j = e + 1
    }
    return 0
}

# ── 3. Tokenizer ──────────────────────────────────────────────────────────
# Fills T[1..TN] (word text or operator), TY[k] ("w" or the operator), TQ[k]
# (the quoted text inside a word) and TM[k] (1 when the word is the argument
# of a message flag, i.e. data).
function end_word() {
    if (!_inw) return
    if (_hdword) { HDN++; HD[HDN] = _cur; _hdword = 0 }
    else if (_redir) _redir = 0                     # a redirection target
    else {
        TN++; T[TN] = _cur; TY[TN] = "w"; TQ[TN] = _qb
        TM[TN] = (_last ~ /^(-m|--message|-F|--file)$/ || _cur ~ /^(-m.|--message=|-F.|--file=)/)
        _last = _cur
    }
    _cur = ""; _inw = 0; _qb = ""
}

function add_op(op) {
    end_word()
    TN++; T[TN] = op; TY[TN] = op; TQ[TN] = ""; TM[TN] = 0
    _last = ""
}

# Queue each pending heredoc body as code and return the index just past the
# last terminator line. Bodies are cut out whole, so an apostrophe inside one
# cannot open a quote that swallows the commands after it.
function read_heredocs(s, i, n,    k, e, line, start) {
    for (k = 1; k <= HDN; k++) {
        start = i
        while (i <= n) {
            e = eol(s, i, n)
            line = (e > 0) ? substr(s, i, e - i) : substr(s, i)
            sub(/\r$/, "", line)
            if (HDD[k]) sub(/^\t+/, "", line)
            if (line == HD[k]) {
                enqueue(substr(s, start, i - start))
                i = (e > 0) ? e + 1 : n + 1
                break
            }
            if (e == 0) { enqueue(substr(s, start)); i = n + 1; break }
            i = e + 1
        }
    }
    HDN = 0
    return i
}

function tokenize(s,    n, i, c, e, q) {
    split("", T); split("", TY); split("", TQ); split("", TM)
    TN = 0; HDN = 0; _cur = ""; _inw = 0; _qb = ""; _redir = 0; _hdword = 0; _last = ""
    n = length(s); i = 1; q = ""
    while (i <= n) {
        c = substr(s, i, 1)
        if (q == "'") {                              # take the whole run up to the closing quote
            e = i
            while (e <= n && substr(s, e, 1) != "'") e++
            _cur = _cur substr(s, i, e - i); _qb = _qb substr(s, i, e - i)
            if (e <= n) q = ""
            i = e + 1; continue
        }
        if (q == "\"") {
            if (c == "\\") {
                e = substr(s, i + 1, 1)
                if (e == "\n") { i += 2; continue }
                if (e == "\"" || e == "\\" || e == "`" || e == "$") { _cur = _cur e; _qb = _qb e; i += 2; continue }
            }
            if (c == "\"") { q = ""; i++; continue }
            if (c == "\\") { _cur = _cur c; _qb = _qb c; i++; continue }   # a backslash that escapes nothing
            e = i
            while (e <= n && (c = substr(s, e, 1)) != "\"" && c != "\\") e++
            _cur = _cur substr(s, i, e - i); _qb = _qb substr(s, i, e - i)
            i = e; continue
        }
        if (c == "\\") {
            e = substr(s, i + 1, 1)
            if (e != "\n") { _cur = _cur e; _inw = 1 }  # backslash-newline: continuation
            i += 2; continue
        }
        if (c == "'" || c == "\"") {
            q = c; _inw = 1; if (_qb != "") _qb = _qb "\n"
            i++; continue
        }
        if (c == " " || c == "\t" || c == "\r") { end_word(); i++; continue }
        if (c == "#" && !_inw) {                     # a comment runs to the end of the line
            e = eol(s, i, n)
            i = (e > 0) ? e : n + 1
            continue
        }
        if (c == "\n") {
            add_op(";"); i++
            if (HDN > 0) i = read_heredocs(s, i, n)
            continue
        }
        if (c == ";" || c == "(" || c == ")") { add_op(";"); i++; continue }
        if (c == "&") {
            e = substr(s, i + 1, 1)
            if (e == "&") { add_op("&&"); i += 2; continue }
            if (e == ">") {                           # &> and &>> redirect
                end_word(); i += 2
                if (substr(s, i, 1) == ">") i++
                _redir = 1; continue
            }
            add_op("&"); i++; continue
        }
        if (c == "|") {
            e = substr(s, i + 1, 1)
            if (e == "|") { add_op("||"); i += 2; continue }
            if (e == "&") i++
            add_op("|"); i++; continue
        }
        if (c == ">" || c == "<") {
            if (_inw && _qb == "" && _cur ~ /^[0-9]+$/) { _cur = ""; _inw = 0 }   # the fd in 2>
            else end_word()
            if (substr(s, i, 3) == "<<<") { i += 3; continue }   # here-string: its word is data for the command, keep it
            if (substr(s, i, 2) == "<<") {
                i += 2; HDD[HDN + 1] = 0
                if (substr(s, i, 1) == "-") { HDD[HDN + 1] = 1; i++ }
                _hdword = 1; continue
            }
            i++
            while (substr(s, i, 1) ~ /[<>&|]/) i++
            _redir = 1; continue
        }
        e = i + 1                                    # an ordinary run up to the next special character
        while (e <= n && index(STOP, substr(s, e, 1)) == 0) e++
        _cur = _cur substr(s, i, e - i); _inw = 1; i = e
    }
    end_word()
}

# ── 4. Judging ────────────────────────────────────────────────────────────
function is_git(w,    lw) {
    lw = tolower(w)
    return (lw == "git" || lw == "git.exe" || lw ~ /[\/\\]git(\.exe)?$/)
}

# The last stage of a pipeline runs a hook script (the documented way to test
# a hook): its echo/printf/cat stages are payload, not commands.
function is_hook_stage(a, b,    w) {
    while (a <= b && T[a] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) a++     # VAR=value prefixes, e.g. PATH=... bash hook.sh
    if (a > b) return 0
    w = T[a]
    if (w == "bash" || w == "sh") { if (a + 1 > b) return 0; w = T[a + 1] }
    return (w ~ /(^|\/)hooks\/[a-z-]+\.sh$/)
}

function judge_all(    k, nst, s, hook) {
    k = 1
    while (k <= TN && VERDICT == "") {
        nst = 0
        while (1) {
            nst++; SA[nst] = k
            while (k <= TN && TY[k] == "w") k++
            SB[nst] = k - 1
            if (k <= TN && TY[k] == "|") { k++; continue }
            break
        }
        hook = is_hook_stage(SA[nst], SB[nst])
        for (s = 1; s <= nst && VERDICT == ""; s++) {
            if (hook && s < nst && SA[s] <= SB[s] && T[SA[s]] ~ /^(echo|printf|cat)$/) { queue_lifted(SA[s], SB[s]); continue }
            judge_stage(SA[s], SB[s])
        }
        k++                                         # past the operator
    }
}

# A word holding the SUBST placeholder had a substitution lifted out of it by
# quote-blind matching. If that matching went wrong, the rest of the
# substitution now sits inside this word, so its quoted text is queued even
# where it would otherwise be skipped: a message argument, an exempt stage.
function queue_lifted(a, b,    k) {
    for (k = a; k <= b; k++) if (TQ[k] != "" && index(T[k], "SUBST")) enqueue(TQ[k])
}

function judge_stage(a, b,    k, e) {
    for (k = a; k <= b; k++) if (TQ[k] != "" && (!TM[k] || index(T[k], "SUBST"))) enqueue(TQ[k])
    for (k = a; k <= b && VERDICT == ""; k++) {
        if (!is_git(T[k])) continue
        e = k + 1
        while (e <= b && !is_git(T[e])) e++
        judge_git(k + 1, e - 1)
        k = e - 1
    }
}

# Global options: these take the next word unless written with "=" (checked
# against git 2.50.1). Any other option is skipped on its own — but if it is a
# long option this list does not know, the word after it might be its value,
# so the word after that is ALSO tried as the subcommand.
function judge_git(a, b,    j, w, amb) {
    j = a; amb = 0
    while (j <= b) {
        w = T[j]
        if (w ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--config-env|--attr-source)$/) { j += 2; amb = 0; continue }
        if (w ~ /^-/) {
            amb = (w ~ /^--/ && w !~ /=/ && w !~ /^--(paginate|no-pager|no-replace-objects|no-lazy-fetch|no-optional-locks|no-advice|bare|exec-path|html-path|man-path|info-path|literal-pathspecs|glob-pathspecs|noglob-pathspecs|icase-pathspecs|version|help)$/)
            j++; continue
        }
        break
    }
    if (j > b) return
    judge_sub(T[j], j + 1, b)
    if (VERDICT == "" && amb && j + 1 <= b) judge_sub(T[j + 1], j + 2, b)
}

function judge_sub(name, a, b,    k, w, dd, pn, i, nm, force, staged, wt, r, L, sv, lv) {
    if (name !~ /^(checkout|restore|reset|clean|branch|push)$/) return
    # options that take a value: without this, "push -f -o ci.skip origin"
    # reads ci.skip as the remote and origin as a branch
    sv = ""; lv = "^$"
    if (name == "push") { sv = "o"; lv = "^--(push-option|repo|receive-pack|exec)$" }
    split("", F); split("", P); pn = 0; dd = 0
    for (k = a; k <= b; k++) {
        w = T[k]
        if (dd) { pn++; P[pn] = w; continue }
        if (w == "--") { dd = 1; F["--"] = 1; continue }
        if (w ~ /^--/) { nm = w; sub(/=.*/, "", nm); F[nm] = 1; if (w !~ /=/ && nm ~ lv) k++; continue }
        if (w ~ /^-[A-Za-z0-9]+$/) {                 # a cluster: -fd, -uf, -f4
            for (i = 2; i <= length(w); i++) {
                L = substr(w, i, 1); F["-" L] = 1
                if (index(sv, L)) { if (i == length(w)) k++; break }   # the rest, or the next word, is its value
            }
            continue
        }
        if (w ~ /^-./) { F[w] = 1; continue }
        pn++; P[pn] = w
    }
    if (name == "checkout") {
        # a path checkout overwrites the working tree; branch names cannot start with "."
        if (F["--"] || F["-f"] || F["--force"]) return block("git checkout (discards uncommitted changes)", "git stash")
        for (i = 1; i <= pn; i++) if (P[i] ~ /^\./) return block("git checkout (discards uncommitted changes)", "git stash")
        return
    }
    if (name == "restore") {
        staged = (F["-S"] || F["--staged"]) && !F["--no-staged"]
        wt = F["-W"] || F["--worktree"]
        if (!(staged && !wt)) block("git restore (discards uncommitted changes)", "git stash")
        return
    }
    if (name == "reset") {
        if (F["--hard"]) block("git reset --hard (destroys all uncommitted changes)", "git stash && git reset")
        return
    }
    if (name == "clean") {
        if (F["-f"] || F["--force"]) block("git clean -f (permanently deletes untracked files)", "git stash --include-untracked")
        return
    }
    if (name == "branch") {
        if (F["-D"] || ((F["-d"] || F["--delete"]) && (F["-f"] || F["--force"])))
            block("git branch -D (deletes branch even if not merged)", "git branch -d (safe delete, fails if not merged)")
        return
    }
    # push: first positional is the remote, the rest are refspecs. -f/--force
    # forces every refspec; a leading + forces that one. --force-with-lease and
    # --force-if-includes are the safe forms and do not count. The main/master
    # test stays unanchored on purpose: anchoring it would let refs/heads/main
    # through, and a miss costs the user's history.
    force = F["-f"] || F["--force"]
    if (force && pn <= 1) return block("git push --force with no explicit branch (the target may be main/master)", "name the branch, or use git push --force-with-lease")
    for (i = 2; i <= pn; i++) {
        r = P[i]
        if ((force || r ~ /^\+/) && r ~ /main|master/) return block("git push --force to main/master (rewrites shared history)", "git push --force-with-lease")
    }
}

# ── Main ──────────────────────────────────────────────────────────────────
BEGIN {
    QMAX = 200; QN = 0; OVERFLOW = 0; VERDICT = ""
    HAVETOOL = 0; TOOL = ""; HAVECMD = 0; CMD = ""
    MSGPOS = "(^|[ \t\n])(-m|--message|-F|--file)(=|[ \t]*(\\\\\n[ \t]*)?)\"?$"
    MSGTAIL = "[ \t\n](-m|--message|-F|--file)(=|[ \t]*(\\\\\n[ \t]*)?)\"?$"
    STOP = " \t\r\n;&|()<>'\"\\"                   # characters that end an unquoted run
}
{ PAYLOAD = (NR == 1) ? $0 : PAYLOAD "\n" $0 }
END {
    parse_payload(PAYLOAD)
    if (HAVETOOL && TOOL != "Bash") { print "OK"; exit }
    if (!HAVECMD) CMD = PAYLOAD                     # cannot isolate the command: scan it all
    enqueue(CMD)
    for (qi = 1; qi <= QN && VERDICT == ""; qi++) {
        tokenize(lift_substitutions(Q[qi]))
        judge_all()
    }
    if (VERDICT != "") print VERDICT
    else if (!OVERFLOW) print "OK"
    # overflow with no verdict prints nothing: the wrapper's coarse check decides
}
AWK

# Payloads over 64 KB skip the parser. BSD awk's substr() costs time in
# proportion to the whole string (measured: 17x slower on a 200 KB string than
# on a 2 KB one), so the character scan is quadratic there: a 1 MB
# heredoc took 156 s on macOS, past any hook timeout — and a timed-out hook
# lets the command run. They get the coarse check below instead.
if [ ${#INPUT} -gt 65536 ]; then
    VERDICT=TOOLONG
else
    VERDICT=$(awk "$PROG" <<<"$INPUT" 2>/dev/null)
fi
TAB=$'\t'

case "$VERDICT" in
    OK)
        exit 0 ;;
    "BLOCK$TAB"*)
        REST=${VERDICT#BLOCK$TAB}
        BLOCKED=${REST%%$TAB*}
        SUGGESTION=${REST#*$TAB} ;;
    *)
        # No verdict from the parser, or too long to parse. Fail loud, but only
        # when the payload mentions git and a guarded subcommand at all — a
        # broken parser must not block every Bash call.
        if printf '%s' "$INPUT" | grep -qiE 'git.*(checkout|restore|reset|clean|branch|push)'; then
            if [ "$VERDICT" = TOOLONG ]; then
                BLOCKED="a command over 64 KB that names git and a subcommand that can destroy work (too long to parse; write large files with the Write tool instead)"
            else
                BLOCKED="a git command that git-guard could not parse (it names a subcommand that can destroy work)"
            fi
            SUGGESTION="git stash"
        else
            exit 0
        fi ;;
esac

echo "Git safety check: Blocked $BLOCKED. This is an irreversible operation — uncommitted work would be lost. Before proceeding: (1) Check git status and git diff to see what would be affected. (2) If changes should be kept, run: $SUGGESTION first. (3) If you're certain the changes should be discarded, tell the user what will be lost and ask for explicit confirmation." >&2
exit 2
