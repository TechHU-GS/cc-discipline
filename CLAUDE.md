# cc-discipline — CLAUDE.md

> General discipline rules are auto-injected via `.claude/rules/`. This file is for project-specific information only.

---

## Project Overview

- **Project name**: cc-discipline
- **One-line description**: Discipline framework for Claude Code — rules, hooks, skills, and agents that keep AI on track
- **Tech stack**: Bash (hooks, init.sh, CLI scripts), Node.js (cli.js cross-platform entry), jq (JSON processing)
- **Key constraints**: Must work on macOS + Linux + Windows (Git Bash). Hook latency baseline is in Known Pitfalls; measure before adding one. Total rules context footprint <3% of 200K context.

---

## Project Structure

```
├── bin/
│   ├── cli.js           ← npm entry point (Node.js, cross-platform)
│   └── cli.sh           ← legacy bash CLI
├── lib/
│   ├── status.sh        ← `cc-discipline status` command
│   ├── doctor.sh        ← `cc-discipline doctor` command
│   ├── stack-remove.sh  ← `cc-discipline remove-stack` command
│   └── hook-hashes      ← sha256 of every shipped framework hook up to 2.14.0 (frozen)
├── init.sh              ← Main install/upgrade script (interactive + --auto)
├── global/
│   └── CLAUDE.md        ← Global rules template (~/.claude/CLAUDE.md)
├── templates/           ← Everything that gets copied to user projects
│   ├── .claude/
│   │   ├── hooks/       ← 7 shell scripts (pre-edit-guard, streak-breaker, etc.)
│   │   ├── rules/       ← 7 core rules (00-01, 03-07; 02 retired) + stacks/ (5 tech stacks)
│   │   ├── skills/      ← 7 skills (commit, self-check, evaluate, think, summary, investigate, coplan)
│   │   ├── agents/      ← reviewer + investigator subagents
│   │   └── settings.json← Hook registration
│   ├── CLAUDE.md        ← Project CLAUDE.md template
│   ├── docs/            ← progress.md + todo.md + debug-log.md templates
│   └── memory/          ← MEMORY.md template
├── tools/               ← Rollout helpers: inventory, rehearse-upgrade, rollout, install-checks (not shipped)
├── docs/
│   ├── progress.md      ← This project's progress log
│   └── debug-log.md     ← This project's debug log
└── package.json         ← npm package config (version is single source of truth)
```

---

## Common Commands

```bash
# Local test: install to a temp project
rm -rf /tmp/test && mkdir /tmp/test && cd /tmp/test && git init && \
  CC_DISCIPLINE_PKG_DIR=~/.cc-discipline \
  bash ~/.cc-discipline/init.sh --auto --stack 7

# Test via cli.js
node bin/cli.js --version
node bin/cli.js init --auto --stack 7

# Test a specific hook
echo '{"tool_name":"Bash","tool_input":{"command":"git checkout ."}}' | \
  bash templates/.claude/hooks/git-guard.sh 2>&1

# Publish to npm
npm publish

# Upgrade in another project
npx cc-discipline@latest upgrade
```

---

## Project Tools

### bin/cli.js
- **Path**: `bin/cli.js`
- **Purpose**: Cross-platform npm entry point. Finds Git Bash on Windows, converts paths, routes subcommands to bash scripts.
- **Usage**: `node bin/cli.js [command] [args]` or via `npx cc-discipline`
- **Created**: 2026-04-03 — Windows compatibility fix

### bin/cli.sh
- **Path**: `bin/cli.sh`
- **Purpose**: Legacy bash CLI entry point. Still works for direct bash usage.
- **Usage**: `bash bin/cli.sh [command] [args]`

### tools/ — rollout helpers (not shipped; `tools/` is absent from package.json `files`)
Written for the 2.14.0–2.15.1 rollouts, which had each rebuilt them from scratch. All take their targets as arguments; the header of each shows the remote invocation for mac-mini and techhu-7940.
- **`tools/inventory.sh <code dir>`** — read-only. Every install found by the `streak-breaker.sh` marker, 6 levels deep, with its version, parser or old git-guard, origin, last commit, and whether it is a (detached) worktree. Run it right before a rollout and have the user approve the list.
- **`tools/rehearse-upgrade.sh <old package> <new tarball>`** — a throwaway project on the old release, upgraded from the new tarball, then the checks the rollout will make. Run it on each machine before rolling out.
- **`tools/rollout.sh <tarball> <code dir> "<approved list>"`** — upgrades approved installs only. It skips and names anything unapproved and any detached linked worktree, names approved installs it cannot find, feeds each installed git-guard five payloads, and prints each installer's "Needs your attention" block verbatim. It reads the expected version from the tarball.
- **`tools/install-checks.sh <repo dir> <older tarball>`** — 13 checks of this working tree's installer: the modified-hook report, the hooks manifest, CRLF tolerance, a 2.13.6 install from the registry, and the `.new` reminders in upgrade, doctor and status. Run it after touching init.sh, lib/doctor.sh, lib/status.sh or lib/hook-hashes.
- **Testing a change on the other machines**: `tar czf` the repo (excluding `.git`), stream it with `ssh host 'tar xzf - -C /tmp/x'`, and run the matrices there. Give GNU tar a `/c/...` path, never `C:/...`, which it takes for a remote host.

### tests/pre-edit-guard-matrix.sh
- **Path**: `tests/pre-edit-guard-matrix.sh`
- **Purpose**: 21-case behaviour matrix for `pre-edit-guard.sh`'s exemption decisions — `docs/` prefix and infix, the extension list (including uppercase), `test`/`spec` in the basename, and the near-misses that must NOT be exempt (`docsite/`, `mydocs/`, `documentation.py`, `.markdown`). **Run after ANY change to the exemption patterns**: v2.13.5 swapped three `echo | grep` pipelines and a `basename` for `case` and parameter expansion, and glob matching is a different engine from ERE.
- **Usage**: `bash tests/pre-edit-guard-matrix.sh [path-to-pre-edit-guard.sh]` (defaults to the templates/ copy). Exits non-zero on any failure.
- **How it observes**: a non-exempt file is detected by the hook emitting its debug-log note on stdout against a fixture whose `docs/debug-log.md` has unresolved hypotheses; an exempt file produces no output at all.
- **Created**: 2026-09-02 — alongside the v2.13.5 builtin rewrite

### tests/session-start-matrix.sh
- **Path**: `tests/session-start-matrix.sh`
- **Purpose**: 61-case matrix for what `session-start.sh` injects: progress.md's status section (not the old `tail -20`), todo.md's *Now* list, and a count of open *Later* items. Covers CRLF files, heading case and trailing spaces, HTML-commented examples, ticked items, a Now list over 20 lines, a progress.md with no status heading, an empty or over-long status, headings inside HTML comments; and, from the 2.14.0 field reports, suffixed and Chinese headings (`## Current Status (date)`, `## 当前态(…)`, `## 当前状态`), `## ` inside a code fence, indented Later sub-items, Later items without a revisit condition, a stale status (older than the newest dated heading, or than two weeks), `<!-- cc-discipline: status-lines=N -->`, date-shaped ticket numbers that are not dates, and an explicit "last updated" line beating the heading's date. "Today" is pinned through `CC_DISCIPLINE_TODAY`. **Run after ANY change to session-start.sh.** The 2.14.0 hook fails 12 of the 24 cases added for 2.15.0.
- **Usage**: `bash tests/session-start-matrix.sh [path-to-session-start.sh]` (defaults to the templates/ copy). Exits non-zero on any failure.
- **Created**: 2026-09-23 — alongside docs/todo.md

### tests/git-guard-matrix.sh
- **Path**: `tests/git-guard-matrix.sh`
- **Purpose**: Regression matrix for `git-guard.sh`, 153 cases:
  - the original 34: bare and compound destructive commands, `bash -c`/`eval`/`sudo`, commit messages *describing* destructive commands, and safe commands;
  - the 14 bypasses from the 2026-09-23 review;
  - parser details: quoted `-C` paths, global options, substitutions, heredocs, line continuations, redirections;
  - false-positive guards, including Claude Code's `$(cat <<'EOF' …)` commit messages;
  - payload parsing: shadowing keys, key order, a missing `command`;
  - the 2026-09-24 code review: a `)` inside a quoted string in `$(...)`, value-taking push options, digit clusters, comments, the other command separators, global options and executable paths;
  - the fallback: a stand-in `awk` that fails on PATH, work-queue overflow, payloads over 64 KB;
  - the 2.14.0 field reports: heredoc bodies that are data (cat, tee, `git commit -F -`, markdown code spans, a 220-span note) and every executing form that must still block (bash, sudo bash, a pipe into bash, write-then-run, python, ssh, a heredoc inside `$(...)` or `<(...)`, unquoted delimiters that expand, script targets such as `x.sh`, `.git/hooks/`, `bin/`), plus `stash drop`/`clear`;
  - the Write-tool note a block carries when the command was inside a heredoc that gets run, and does not carry otherwise.

  **Run this after ANY change to git-guard** — it is the only guard that prevents data loss, and a miss is unrecoverable while a false positive costs one turn.
- **Usage**: `bash tests/git-guard-matrix.sh [path-to-git-guard.sh]` (defaults to the templates/ copy; pass `.claude/hooks/git-guard.sh` to check the installed one). Exits non-zero on any failure.
- **Note**:
  - Payloads are JSON-escaped by awk, not `printf` or `sed`, so newlines survive and no backslash level is lost.
  - **PASS means exit 0 exactly**; any code other than 0 or 2 fails as `ERROR rc=N`.
  - Not shipped to npm — `tests/` is absent from package.json `files`.
- **Created**: 2026-07-30 — alongside the v2.12.3 message-argument fix; rebuilt 2026-09-23 with the awk parser. The pre-rewrite hook failed 26 of the first 83 cases, including all 14 bypasses, and 45 of 117 after the 2026-09-24 additions.

---

## Code Style

- Shell scripts: `set -e` on Unix, disabled on Windows Git Bash (MINGW/MSYS)
- Hook output: exit 0 + JSON stdout for additionalContext, exit 2 + stderr for blocking
- Version: single source of truth in `package.json`, init.sh reads via `CC_DISCIPLINE_VERSION` env var
- Rules: concise, actionable, no filler. Each rule must earn its context footprint.

---

## Known Pitfalls

Rules only. The incidents behind them are in `docs/progress.md` — do not restate them here, or one of the two copies will go stale.

### Cross-platform

- **`stat -c` BEFORE `stat -f`, and validate the result is a bare integer before arithmetic.** The order is not symmetric: on GNU stat `-f` means *show filesystem status* and **succeeds**, printing a multi-line dump, so a `-f || -c` chain never reaches its fallback. `case "$V" in ''|*[!0-9]*) V="" ;; esac`.
- **Never `cp -r "$dir/" dest/`.** With a trailing slash GNU copies the *directory*, BSD copies its *contents*. Copy into an explicit destination: `mkdir -p "$dst"; cp -R "$src"* "$dst/"`.
- **macOS `/tmp` is `/private/tmp`.** Hook JSON `cwd` may carry either; check both paths.
- **`set -e` is disabled on MINGW/MSYS** — too many commands fail silently there.
- **BSD awk's `substr()` costs time proportional to the whole string, not the slice.** Measured: 200,000 calls of `substr(s, i, 1)` take 37 ms on a 2 KB string and 636 ms on a 200 KB one under BSD awk 20200816; gawk takes about 200 ms for both. Any character-by-character scan is therefore quadratic on macOS: git-guard took 9 s on a 200 KB command and 156 s on a 1 MB one. Cap the input size before scanning — git-guard skips its parser above 64 KB — and time long inputs on the mac, since gawk hides the problem.
- **Test installs on macOS AND Windows before releasing.** The `cp -r` bug was macOS-only and shipped through three versions while every Windows test passed.

### Hooks

- **Every `jq` read needs a grep/sed fallback — for EVERY field, not just the obvious one.** git-guard once read `tool_name` with jq alone, so on any jq-less machine it exited 0 at the first check and every destructive-git guard below it was dead code from day one. Audit with `grep -n 'jq -r' templates/.claude/hooks/*.sh`: every hit must sit inside a `command -v jq` branch that has an `else`.
- **Choose each hook's failure direction deliberately and say so in a comment.** git-guard fails **loud** — a spurious prompt costs one turn, a miss costs the user's work. post-error-remind fails **silent** — a false positive misleads.
- **Run the matrices after touching either guard's matching**: `tests/git-guard-matrix.sh` (153 cases) and `tests/pre-edit-guard-matrix.sh` (21); after touching `session-start.sh`, run `tests/session-start-matrix.sh` (61). Glob, ERE and BRE are different engines; equivalence must be demonstrated, not assumed.
- **A heredoc body is data only when git-guard can see it goes nowhere that runs.** Since 2.15.0: it must feed `cat`, `tee` or `git commit -F -`, not write a script (`x.sh`, `.git/hooks/`, `bin/`), pipe only into sinks or plain filters, sit in the command Claude typed rather than inside a substitution, and nothing else in the command may run an interpreter, a `./path` or a script. Everything else is code. This replaced "every body is code" after three field reports, because appending notes that *name* destructive commands to progress.md was blocked daily. It is an allowlist: widen it only together with matrix cases for the executing forms it could let through. Quoted text inside an interpreter heredoc (`python - <<'PY'`) is still code — judging what a python script executes is not reliable — so write such scripts with the Write tool and run the file; since 2.15.1 the block message says exactly that.
- **Never name an awk variable after a gawk built-in** (`RT`, `FPAT`, `IGNORECASE`, `PROCINFO`, `ERRNO`, …). Using `RT` as an array made gawk die with "attempt to use scalar `RT' as an array"; BSD awk has no such variable and runs fine, so only Linux and Windows fail. The fallback kept git-guard failing loud, and only the matrix showed it.
- **A hook matrix must count only exit 0 as PASS.** Claude Code treats any exit other than 2 as a non-blocking error, so a hook that crashes lets the command run; a matrix that counts every non-2 code as a pass cannot see that.
- **Hook latency** (MS-01, Git Bash, jq absent; the box's load moves these by ±50ms, so compare old and new side by side): git-guard ~190–280ms since the awk rewrite (it was ~900ms), with `action-counter` at ~350ms the critical path of every Bash call; session-start ~420ms in 2.15.0 (2.14.0: ~900ms), once per session. On Windows every fork costs tens of milliseconds: parse awk output with `while read` and `case`, not one `printf | sed` per field. On macOS git-guard takes ~10ms.
- **Edit-path latency baseline** (Git Bash, jq absent): the three `PreToolUse` hooks run in parallel and `pre-edit-guard` is the critical path — ~150ms for an exempt file, ~650ms for source. Do not add a fourth hook to that path without measuring.

### Shell escaping

Four separate failures in one session came from this family. Prefer Python with explicit character codes over `sed` for any content edit containing shell or regex metacharacters.

- **`printf` eats one backslash level.** `printf 'a\nb'` emits a REAL newline; `printf 'x\r'` a REAL carriage return. For a literal backslash sequence use `awk 'BEGIN{printf "a%cn", 92}'`, or rephrase to avoid it.
- **In `sed`'s BRE, `\|` is ALTERNATION, not a literal pipe.** One such pattern, meant to fix a single string, replaced 11 unrelated fragments across `progress.md`.
- **`grep -c` exits 1 on zero matches.** Use `VAR=$(grep -c ...) || VAR=0` — never `grep -c ... || echo 0`, which prints `0` twice because grep already printed one.
- **`grep '\*\.js'` matches `*.json`.** Anchor it: `grep -qE '^\*\.js[[:space:]]'`.
- **Python is a native Windows binary and cannot open MSYS paths.** Pass `C:/Users/...`, never `/c/Users/...` — the failure is `FileNotFoundError`, which reads as "the thing was never created". Two more on this box: Python's stdout is GBK, so printing a character like ✅ crashes a script mid-run (file writes in UTF-8 are unaffected) — set `PYTHONIOENCODING=utf-8`; and `glob` skips dot-directories, so a scan of `.claude/` needs `os.walk`.

### Release

- **Version lives only in `package.json`.** init.sh reads it through the cli.js env var; no hardcoded versions anywhere.
- **`.gitattributes` forces `eol=lf`** for `*.sh`, `*.md`, `*.json`, `*.js` and the six extensionless files: `.cc-discipline-version`, `.cc-discipline-skills.manifest`, `.cc-discipline-hooks.manifest`, `lib/hook-hashes`, `.gitignore`, and `.gitattributes` itself. **A new extensionless file needs its own line** — `lib/hook-hashes` shipped without one and git warned it would become CRLF on the next checkout, which would have reported every old hook as modified. **`npm publish` packs the WORKING TREE, not git**, so a clean `git show` proves nothing. Verify:
  ```bash
  find . -name node_modules -prune -o -name .git -prune -o -type f \
    \( -name '*.sh' -o -name '*.md' -o -name '*.json' -o -name '*.js' \) -print \
    | xargs file | grep CR          # must print nothing
  head -1 bin/cli.js | cat -A       # must end node$, not node^M$
  ```
- **`npx cc-discipline` cannot work inside this repo** — npx resolves the name against the local `package.json`. Use `node bin/cli.js`. It fails with a *message*, so a filtering `grep` shows nothing and reads as "ran, nothing changed"; always check `.claude/.cc-discipline-version` afterwards.
- **Publishing needs two-factor authentication, and with a passkey it needs a real terminal.** The account's 2FA is a passkey in Bitwarden, so there is no six-digit code, and `npm publish` run through Claude Code's `!` prefix fails with EOTP: that shell is not interactive, so npm never offers its browser step. The user runs `npm publish` in a terminal window of their own. Before that, `npm publish --dry-run` here checks the package, and `npm whoami` checks the login.
- **After publishing, wait for the registry, then force npm past its own cache.** The registry serves a new version roughly 80s after `npm publish` returns success, and npm's *local metadata cache* lags that independently — `npx cc-discipline@<version>` fails with `ETARGET` while the version is demonstrably live. Roll out with `npx -y --prefer-online cc-discipline@<version>`, and read the version marker afterwards rather than trusting installer output. Compare `npm view cc-discipline@<version> dist.shasum` with the sha1 of the tarball you rehearsed: `npm pack` is reproducible, so they must match.

### Rollout

- **Use `tools/inventory.sh`, `tools/rehearse-upgrade.sh` and `tools/rollout.sh`** — they encode the rules below.
- **Enumerate installs by the marker `.claude/hooks/streak-breaker.sh`, never by the version file, and search deep (`find -maxdepth 6`).** The oldest installs have no version file at all, so a version-based inventory is structurally blind to exactly the ones most in need of upgrading. Nested installs exist too: two under mac-mini's `GS_IC/designs/` sat on 2.6.1 through every rollout until 2026-09-24.
- **Remote rollout needs a LOGIN shell**: `ssh host 'bash -ls -- <args>' < script.sh`. Without `-l` no profile is sourced and `npx` is not on PATH — six installs failed together this way.
- **`npx` inside `find | while read` eats the loop's stdin.** Collect the list into a variable and iterate with `for`, or redirect the command's stdin from `/dev/null`.
- **To deploy an unpublished version, `npm pack` and install from the tarball with `npx -y --package=<tgz> cc-discipline upgrade`.** A bare Windows path — `npx -y C:/…/cc-discipline-X.tgz upgrade` — exits 0 and does nothing; `file:<tgz>` also works. Rehearse on a throwaway 2.x project on each machine first, then read the version marker afterwards.
- **Keep each install's upgrade output and surface its "Needs your attention" block.** Since 2.15.0 init.sh names every framework hook it replaced over local changes, and every skill it kept with a `.new` beside it, right under "Setup complete!". The 2.14.0 rollout wrote that output to a log and deleted it on success, so nobody saw that ~15 installs had a `.new` waiting. Framework hooks are still always replaced (backed up to `.claude/.backup-<time>/hooks/`); modified ones are detected through `.claude/.cc-discipline-hooks.manifest` and, for older installs, `lib/hook-hashes`, which is frozen and must not be regenerated.
- **Re-inventory right before rolling out, and compare with the list the user approved.** Installs appear within hours: a worktree created thirteen minutes before the 2.15.0 rollout was upgraded unasked, because the script enumerates live. Print the targets, diff them against the approved list, and ask about anything new before touching it. Skip linked worktrees with a detached HEAD outright: they are usually scratch checkouts of HEAD, made to compare against.
- **Verify functionally, not by file content.** Grepping the installed file proves it arrived; feeding a guard payloads and checking exit codes proves it decides correctly.

### Skills

- **Skills are conffiles.** A modified skill is preserved and the current template is written beside it as `SKILL.md.new`; `doctor` and `status` list the ones still waiting. There is no need to hand-save `/self-check`'s Project-specific Checks before upgrading — that was required before 2.12.2 and is not now. Extra user-authored skill dirs are never touched.
- **Retiring a core rule takes five edits, not one.** Core rules are overwritten on every upgrade, so a rule dropped only from `templates/` stays in every existing install indefinitely. Delete the template, remove its `cp` line in `init.sh`, add it to the retired-rules `rm` block there (which runs only in upgrade mode — in append mode a file by that name is the user's own), drop it from `lib/doctor.sh`'s loop (otherwise `doctor` fails on every install), and update both READMEs.
- **Installs that jumped from `<2.12.2` have no manifest**, so retired skills are never removed there and will persist indefinitely.

---

## Compact Supplement

When compacting, preserve:
- Current npm version and what's published vs unpublished
- Which files were changed since last publish
- Any Windows-specific fixes in progress
- The relationship: templates/ = source of truth, .claude/ = local install (dogfood)
