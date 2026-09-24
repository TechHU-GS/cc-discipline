#!/bin/bash
# cc-discipline: Guard against destructive git commands
# PreToolUse on Bash — blocks git checkout/restore/reset --hard/clean -f,
# branch -D, stash drop/clear and force-pushes to main/master until the user
# confirms.
#
# Failure direction: LOUD. A spurious confirmation prompt costs one turn; a
# miss costs the user's uncommitted work.
#
# How it decides (redesigned 2026-09-23 after a review found 14 destructive
# forms that the old one-regex-per-rule version let through):
#   1. Read the payload exactly: top-level tool_name, and command directly
#      inside tool_input — the paths jq would read, without needing jq.
#   2. Lift every $(...) and `...` out into its own work item: substitutions
#      execute even inside a quoted -m message. Heredoc bodies are cut out in
#      the same pass.
#   3. Tokenize with bash quoting rules and split into single commands at
#      ; && || | & ( ) and newlines. Quoted text is also queued as its own work
#      item (bash -c "...", eval "...", ssh host "..."), except the argument of
#      -m/--message/-F/--file, which is data. A heredoc body is data when it
#      only feeds cat, tee or git commit -F - and nothing in the command runs
#      code; otherwise it is judged as code (decide_heredocs). Until 2.15.0
#      every body was code, and appending notes that NAME these commands to a
#      file was blocked every day.
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
# Tests: tests/git-guard-matrix.sh in the cc-discipline repository; they are
# not installed with the hooks. To try a case by hand, write the command into a
# file first: this guard reads quoted text as code, so a case typed inline
# blocks the test command itself.

IFS= read -r -d '' INPUT

IFS= read -r -d '' PROG <<'AWK'
function has_git(s) { return index(tolower(s), "git") > 0 }

function enqueue(s) {
    if (!has_git(s)) return        # no rule can fire without a git word
    if (s in SEEN) return          # judged once: long notes repeat the same `git ...` spans
    if (QN >= QMAX) { OVERFLOW = 1; return }
    SEEN[s] = 1; QN++; Q[QN] = s
    QH[QN] = (ENQ_HD || CURHD)     # from a heredoc body judged as code, or from text inside one
}

# A block found inside a heredoc body judged as code carries a note: the usual
# case is a script that only edits a file and merely NAMES the command (a
# report asked for python heredocs to pass; judging what python code executes
# is not reliable, so the guard says what to do instead).
function block(reason, hint) {
    if (VERDICT == "") VERDICT = "BLOCK\t" reason "\t" hint (CURHD ? "\t" HDNOTE : "")
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

# ── 2. Command substitutions and heredoc bodies ───────────────────────────
# Substitutions are matched by depth counting that ignores quotes inside them,
# so a ")" inside a quoted string can end one early. Every character still ends
# up either in the returned string or in a queued item — but the leftover can
# land inside a message argument, which is not scanned; queue_lifted() covers
# that case. Quotes OUTSIDE substitutions are tracked: single-quoted text is
# literal (a quoted word that bash -c or ssh runs is queued by the tokenizer
# and lifted then), and a "<<" inside quotes is not a heredoc.
#
# Heredoc bodies are cut out here and kept aside in PB[], so no quote or
# backtick inside one can confuse what follows it. A QUOTED delimiter means the
# body is literal, so nothing in it is lifted; an unquoted one expands, so its
# substitutions are lifted like any others. Whether a body is then judged as
# code is decided after tokenizing (decide_heredocs). The commit-message form
# -m "$(cat <<'EOF' ... EOF)" is dropped on purpose (message_heredoc_end).
function lift_substitutions(s, nohd,    n, i, c, out, j, depth, st, w, mp, q, hn) {
    n = length(s); out = ""; i = 1; st = 1; q = ""; hn = 0   # s[st..i-1] is pending, not yet in out
    if (!nohd) PBN = 0
    while (i <= n) {
        c = substr(s, i, 1)
        if (q == "'") { if (c == "'") q = ""; i++; continue }
        if (c == "\\") { i += 2; continue }                 # an escaped character is literal
        if (q == "\"") { if (c == "\"") { q = ""; i++; continue } }
        else if (c == "'" || c == "\"") { q = c; i++; continue }
        else if (!nohd && c == "<" && substr(s, i + 1, 1) == "<" && substr(s, i + 2, 1) != "<" \
                 && substr(s, i - 1, 1) != "<" && (j = heredoc_op(s, i + 2, n)) > 0) {
            hn++; HLD[hn] = HOP_DELIM; HLDASH[hn] = HOP_DASH; HLQ[hn] = HOP_QUOTED
            i = j; continue
        }
        else if (c == "\n" && hn > 0) {
            out = out substr(s, st, i - st + 1)            # up to and including the newline
            i = cut_bodies(s, i + 1, n, hn); hn = 0; st = i; continue
        }
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

# After "<<": optional "-", blanks, then a delimiter that is 'X', "X", \X or a
# bare word. Sets HOP_DELIM, HOP_DASH, HOP_QUOTED; returns the index just past
# the delimiter, or 0 when there is none.
function heredoc_op(s, j, n,    dash, q, k) {
    dash = 0
    if (substr(s, j, 1) == "-") { dash = 1; j++ }
    while (substr(s, j, 1) ~ /[ \t]/) j++
    q = substr(s, j, 1)
    if (q == "'" || q == "\"") {
        k = j + 1
        while (k <= n && substr(s, k, 1) != q && substr(s, k, 1) != "\n") k++
        if (substr(s, k, 1) != q) return 0
        HOP_DELIM = substr(s, j + 1, k - j - 1); HOP_QUOTED = 1; j = k + 1
    } else {
        HOP_QUOTED = 0
        if (q == "\\") { HOP_QUOTED = 1; j++ }
        k = j
        while (k <= n && substr(s, k, 1) ~ /[A-Za-z0-9_.-]/) k++
        HOP_DELIM = substr(s, j, k - j); j = k
    }
    if (HOP_DELIM == "") return 0
    HOP_DASH = dash
    return j
}

# Cut the bodies of the hn heredocs opened on the line that just ended; s[i] is
# the first body line. Returns the index just past the last terminator line. A
# body with no terminator runs to the end of the string, as it does in bash.
function cut_bodies(s, i, n, hn,    k, e, line, start, body) {
    for (k = 1; k <= hn; k++) {
        start = i
        while (1) {
            if (i > n) { body = substr(s, start); break }
            e = eol(s, i, n)
            line = (e > 0) ? substr(s, i, e - i) : substr(s, i)
            sub(/\r$/, "", line)
            if (HLDASH[k]) sub(/^\t+/, "", line)
            if (line == HLD[k]) { body = substr(s, start, i - start); i = (e > 0) ? e + 1 : n + 1; break }
            if (e == 0) { body = substr(s, start); i = n + 1; break }
            i = e + 1
        }
        PBN++; PB[PBN] = HLQ[k] ? body : lift_substitutions(body, 1)
    }
    return i
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
    if (_hdword) _hdword = 0                         # a heredoc delimiter
    else if (_redir) { _redir = 0; RN++; RDT[RN] = _cur; RDA[RN] = TN }   # a redirection target, kept aside
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

function tokenize(s,    n, i, c, e, q) {
    split("", T); split("", TY); split("", TQ); split("", TM)
    TN = 0; HOPN = 0; RN = 0; _cur = ""; _inw = 0; _qb = ""; _redir = 0; _hdword = 0; _last = ""
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
        if (c == "\n") { add_op(";"); i++; continue }  # heredoc bodies were cut out by the lift pass
        # A backtick left here is one the lift pass read as quoted: still a boundary.
        if (c == ";" || c == "(" || c == ")" || c == "`") { add_op(";"); i++; continue }
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
            if (substr(s, i, 2) == "<<") {                # the body is already cut out
                i += 2
                if (substr(s, i, 1) == "-") i++
                HOPN++; HOPAT[HOPN] = TN; _hdword = 1; continue
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

# ── 3b. Heredoc bodies: data or code ──────────────────────────────────────
# A body is data only when all of this holds, and code otherwise:
#   - it belongs to the command Claude typed; a heredoc inside a substitution
#     or a quoted string runs wherever that text runs;
#   - its command is a data sink (cat, tee, git commit -F -) that is not
#     writing a script (x.sh, .git/hooks/..., bin/...), and every later stage
#     of its pipeline is a sink or a plain filter: cat <<X | bash is code;
#   - nothing in the command runs an interpreter or a script, and there is no
#     <( or >(: cat > x.sh <<X ... && bash x.sh writes code and then runs it;
#   - the tokenizer found exactly as many "<<" as the lift pass cut bodies.
#     When the two passes disagree, nothing is trusted.
# This is a list of what may pass, not of what must be blocked, so a command
# it does not know keeps its heredoc judged as code.
function decide_heredocs(s,    k, allcode) {
    if (PBN == 0) return
    allcode = (CURQI != 1 || HOPN != PBN || index(s, "<(") || index(s, ">(") || item_runs())
    ENQ_HD = 1
    for (k = 1; k <= PBN; k++)
        if (allcode || !heredoc_is_data(HOPAT[k])) enqueue(PB[k])
    ENQ_HD = 0
}

function base(w) { w = tolower(w); sub(/.*[\/\\]/, "", w); sub(/\.exe$/, "", w); return w }

# Index of the command word of stage T[a..b], past VAR=value assignments and
# wrappers such as sudo or env; 0 when there is none.
function cmd_at(a, b,    k) {
    k = a
    while (k <= b) {
        if (T[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { k++; continue }
        if (T[k] ~ /^(sudo|env|nohup|time|command|nice)$/) { k++; while (k <= b && T[k] ~ /^-/) k++; continue }
        return k
    }
    return 0
}

# A file that will be run later: a script extension, or a hooks/ or bin/ path.
function script_like(w) {
    return (w ~ /\.(sh|bash|zsh|py|pl|rb|js|mjs|cjs|ts|ps1|psm1|bat|cmd)$/ || w ~ /(^|[\/\\])(hooks|\.husky|bin)[\/\\]/)
}

function sink_stage(a, b,    k, c, j) {
    k = cmd_at(a, b); if (!k) return 0
    c = base(T[k])
    # cat > x.sh <<EOF writes a script: that body is code, run now or later
    for (j = 1; j <= RN; j++) if (RDA[j] >= a && RDA[j] <= b && script_like(RDT[j])) return 0
    if (c == "cat") return 1
    if (c == "tee") { for (j = k + 1; j <= b; j++) if (script_like(T[j])) return 0; return 1 }
    if (c != "git") return 0
    for (j = k + 1; j <= b && T[j] != "commit"; j++) ;
    for (; j <= b; j++)
        if ((T[j] ~ /^(-F|--file)$/ && T[j + 1] == "-") || T[j] == "--file=-" || T[j] == "-F-") return 1
    return 0
}

function filter_stage(a, b,    k) {
    k = cmd_at(a, b)
    return k && base(T[k]) ~ /^(grep|egrep|fgrep|head|tail|wc|sort|uniq|cut|tr)$/
}

# Does anything in this command run code? Any word naming an interpreter, a
# ./path, or a stage whose command is a script file.
function item_runs(    k, a, c) {
    for (k = 1; k <= TN; k++)
        if (TY[k] == "w" && (base(T[k]) ~ RUNNERS || T[k] ~ /^\.\.?[\/\\]/)) return 1
    a = 1
    for (k = 1; k <= TN + 1; k++) {
        if (k > TN || TY[k] != "w") {
            if (a < k && (c = cmd_at(a, k - 1)) && T[c] ~ /\.(sh|bash|zsh|py|pl|rb|js|mjs|ts|ps1|bat|cmd)$/) return 1
            a = k + 1
        }
    }
    return 0
}

function heredoc_is_data(p,    a, b, k, st, own) {
    if (p < 1 || TY[p] != "w") p++                  # "<<" before any word: the next word owns it
    if (p > TN || TY[p] != "w") return 0
    a = p; while (a > 1 && (TY[a - 1] == "w" || TY[a - 1] == "|")) a--
    b = p; while (b < TN && (TY[b + 1] == "w" || TY[b + 1] == "|")) b++
    own = 0; st = a
    for (k = a; k <= b + 1; k++) {
        if (k > b || TY[k] == "|") {
            if (st <= p && p <= k - 1) { if (!sink_stage(st, k - 1)) return 0; own = 1 }
            else if (own && !(sink_stage(st, k - 1) || filter_stage(st, k - 1))) return 0
            st = k + 1
        }
    }
    return own
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
    if (name !~ /^(checkout|restore|reset|clean|branch|push|stash)$/) return
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
    if (name == "stash") {
        # The hint for reset --hard is "git stash first", which makes the stash
        # the backup; dropping it is the same loss one step later.
        if (pn >= 1 && P[1] ~ /^(drop|clear)$/)
            block("git stash " P[1] " (permanently deletes stashed changes)", "git stash list and git stash show -p to see what it holds (a dropped stash can only be recovered with git fsck)")
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
    QMAX = 1000; QN = 0; OVERFLOW = 0; VERDICT = ""; ENQ_HD = 0; CURHD = 0
    HDNOTE = "This was inside a heredoc that gets run (fed to an interpreter such as python or bash, or written as a script), which this guard judges as code. If the script only edits files and merely names the command, write it to a file with the Write tool and run that file instead."
    HAVETOOL = 0; TOOL = ""; HAVECMD = 0; CMD = ""
    MSGPOS = "(^|[ \t\n])(-m|--message|-F|--file)(=|[ \t]*(\\\\\n[ \t]*)?)\"?$"
    MSGTAIL = "[ \t\n](-m|--message|-F|--file)(=|[ \t]*(\\\\\n[ \t]*)?)\"?$"
    STOP = " \t\r\n;&|()<>'\"\\`"                  # characters that end an unquoted run
    RUNNERS = "^(bash|sh|zsh|dash|ksh|fish|ash|busybox|python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php|lua|tclsh|osascript|pwsh|powershell|cmd|ssh|xargs|parallel|eval|exec|source|\\.)$"
}
{ PAYLOAD = (NR == 1) ? $0 : PAYLOAD "\n" $0 }
END {
    parse_payload(PAYLOAD)
    if (HAVETOOL && TOOL != "Bash") { print "OK"; exit }
    if (!HAVECMD) CMD = PAYLOAD                     # cannot isolate the command: scan it all
    enqueue(CMD)
    for (qi = 1; qi <= QN && VERDICT == ""; qi++) {
        CURQI = qi; CURHD = QH[qi]
        LIFTED = lift_substitutions(Q[qi], 0)
        tokenize(LIFTED)
        decide_heredocs(LIFTED)
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
    # awk runs with LC_ALL=C: byte semantics everywhere, which is how this code is
    # written. Under a UTF-8 locale, macOS's awk is still byte-based for substr()
    # and length(), but a regex match against half a multi-byte character is
    # fatal ("towc: multibyte conversion failure"). 2.15.1 died that way on
    # "## 2026-08-04（三）" and fell back to the file's tail (2026-09-25).
    VERDICT=$(LC_ALL=C awk "$PROG" <<<"$INPUT" 2>/dev/null)
fi
TAB=$'\t'
NOTE=""    # never inherited from the environment

case "$VERDICT" in
    OK)
        exit 0 ;;
    "BLOCK$TAB"*)
        REST=${VERDICT#BLOCK$TAB}
        BLOCKED=${REST%%$TAB*}
        REST=${REST#*$TAB}
        SUGGESTION=${REST%%$TAB*}
        case "$REST" in *"$TAB"*) NOTE=${REST#*$TAB} ;; esac ;;
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

echo "Git safety check: Blocked $BLOCKED. This is an irreversible operation — uncommitted work would be lost. Before proceeding: (1) Check git status and git diff to see what would be affected. (2) If changes should be kept, run: $SUGGESTION first. (3) If you're certain the changes should be discarded, tell the user what will be lost and ask for explicit confirmation.${NOTE:+ $NOTE}" >&2
exit 2
