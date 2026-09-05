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
│   └── stack-remove.sh  ← `cc-discipline remove-stack` command
├── init.sh              ← Main install/upgrade script (interactive + --auto)
├── global/
│   └── CLAUDE.md        ← Global rules template (~/.claude/CLAUDE.md)
├── templates/           ← Everything that gets copied to user projects
│   ├── .claude/
│   │   ├── hooks/       ← 7 shell scripts (pre-edit-guard, streak-breaker, etc.)
│   │   ├── rules/       ← 8 core rules (00-07) + stacks/ (5 tech stacks)
│   │   ├── skills/      ← 7 skills (commit, self-check, evaluate, think, summary, investigate, coplan)
│   │   ├── agents/      ← reviewer + investigator subagents
│   │   └── settings.json← Hook registration
│   ├── CLAUDE.md        ← Project CLAUDE.md template
│   ├── docs/            ← progress.md + debug-log.md templates
│   └── memory/          ← MEMORY.md template
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

### tests/pre-edit-guard-matrix.sh
- **Path**: `tests/pre-edit-guard-matrix.sh`
- **Purpose**: 21-case behaviour matrix for `pre-edit-guard.sh`'s exemption decisions — `docs/` prefix and infix, the extension list (including uppercase), `test`/`spec` in the basename, and the near-misses that must NOT be exempt (`docsite/`, `mydocs/`, `documentation.py`, `.markdown`). **Run after ANY change to the exemption patterns**: v2.13.5 swapped three `echo | grep` pipelines and a `basename` for `case` and parameter expansion, and glob matching is a different engine from ERE.
- **Usage**: `bash tests/pre-edit-guard-matrix.sh [path-to-pre-edit-guard.sh]` (defaults to the templates/ copy). Exits non-zero on any failure.
- **How it observes**: a non-exempt file is detected by the hook emitting its debug-log note on stdout against a fixture whose `docs/debug-log.md` has unresolved hypotheses; an exempt file produces no output at all.
- **Created**: 2026-09-02 — alongside the v2.13.5 builtin rewrite

### tests/git-guard-matrix.sh
- **Path**: `tests/git-guard-matrix.sh`
- **Purpose**: Regression matrix for `git-guard.sh` — 25 cases split into "must still block" (bare destructive commands, compound `&&`/`;`, `bash -c`, `eval`, `sudo` prefix), "must pass" (commit messages *describing* destructive commands, `-m`/`--message`/`-F`, `grep -F`), and "safe commands still pass". **Run this after ANY change to git-guard's matching** — it is the only guard that prevents data loss, and a miss is unrecoverable while a false positive costs one turn.
- **Usage**: `bash tests/git-guard-matrix.sh [path-to-git-guard.sh]` (defaults to the templates/ copy; pass `.claude/hooks/git-guard.sh` to check the installed one). Exits non-zero on any failure.
- **Note**: builds payloads with `sed`-based escaping rather than `printf`, because `printf` silently eats a backslash level (see Known Pitfalls). Not shipped to npm — `tests/` is absent from package.json `files`.
- **Created**: 2026-07-30 — alongside the v2.12.3 message-argument fix

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
- **Test installs on macOS AND Windows before releasing.** The `cp -r` bug was macOS-only and shipped through three versions while every Windows test passed.

### Hooks

- **Every `jq` read needs a grep/sed fallback — for EVERY field, not just the obvious one.** git-guard once read `tool_name` with jq alone, so on any jq-less machine it exited 0 at the first check and every destructive-git guard below it was dead code from day one. Audit with `grep -n 'jq -r' templates/.claude/hooks/*.sh`: every hit must sit inside a `command -v jq` branch that has an `else`.
- **Choose each hook's failure direction deliberately and say so in a comment.** git-guard fails **loud** — a spurious prompt costs one turn, a miss costs the user's work. post-error-remind fails **silent** — a false positive misleads.
- **Run the matrices after touching either guard's matching**: `tests/git-guard-matrix.sh` (34 cases) and `tests/pre-edit-guard-matrix.sh` (21). Glob, ERE and BRE are different engines; equivalence must be demonstrated, not assumed.
- **git-guard also matches destructive command names inside heredoc bodies and quoted script text**, so writing documentation *about* those commands through a shell heredoc is blocked. Use the Write tool, which the guard does not gate. **Do not "fix" this** — blanking heredoc bodies would open a real hole, since a heredoc fed to `bash` executes.
- **Edit-path latency baseline** (Git Bash, jq absent): the three `PreToolUse` hooks run in parallel and `pre-edit-guard` is the critical path — ~150ms for an exempt file, ~650ms for source. Do not add a fourth hook to that path without measuring.

### Shell escaping

Four separate failures in one session came from this family. Prefer Python with explicit character codes over `sed` for any content edit containing shell or regex metacharacters.

- **`printf` eats one backslash level.** `printf 'a\nb'` emits a REAL newline; `printf 'x\r'` a REAL carriage return. For a literal backslash sequence use `awk 'BEGIN{printf "a%cn", 92}'`, or rephrase to avoid it.
- **In `sed`'s BRE, `\|` is ALTERNATION, not a literal pipe.** One such pattern, meant to fix a single string, replaced 11 unrelated fragments across `progress.md`.
- **`grep -c` exits 1 on zero matches.** Use `VAR=$(grep -c ...) || VAR=0` — never `grep -c ... || echo 0`, which prints `0` twice because grep already printed one.
- **`grep '\*\.js'` matches `*.json`.** Anchor it: `grep -qE '^\*\.js[[:space:]]'`.
- **Python is a native Windows binary and cannot open MSYS paths.** Pass `C:/Users/...`, never `/c/Users/...` — the failure is `FileNotFoundError`, which reads as "the thing was never created".

### Release

- **Version lives only in `package.json`.** init.sh reads it through the cli.js env var; no hardcoded versions anywhere.
- **`.gitattributes` forces `eol=lf`** for `*.sh`, `*.md`, `*.json`, `*.js` and the four extensionless files: `.cc-discipline-version`, `.cc-discipline-skills.manifest`, `.gitignore`, and `.gitattributes` itself. **`npm publish` packs the WORKING TREE, not git**, so a clean `git show` proves nothing. Verify:
  ```bash
  find . -name node_modules -prune -o -name .git -prune -o -type f \
    \( -name '*.sh' -o -name '*.md' -o -name '*.json' -o -name '*.js' \) -print \
    | xargs file | grep CR          # must print nothing
  head -1 bin/cli.js | cat -A       # must end node$, not node^M$
  ```
- **`npx cc-discipline` cannot work inside this repo** — npx resolves the name against the local `package.json`. Use `node bin/cli.js`. It fails with a *message*, so a filtering `grep` shows nothing and reads as "ran, nothing changed"; always check `.claude/.cc-discipline-version` afterwards.
- **After publishing, wait for the registry, then force npm past its own cache.** The registry serves a new version roughly 80s after `npm publish` returns success, and npm's *local metadata cache* lags that independently — `npx cc-discipline@<version>` fails with `ETARGET` while the version is demonstrably live. Roll out with `npx -y --prefer-online cc-discipline@<version>`, and read the version marker afterwards rather than trusting installer output.

### Rollout

- **Enumerate installs by the marker `.claude/hooks/streak-breaker.sh`, never by the version file.** The oldest installs have no version file at all, so a version-based inventory is structurally blind to exactly the ones most in need of upgrading.
- **Remote rollout needs a LOGIN shell**: `ssh host 'bash -ls -- <args>' < script.sh`. Without `-l` no profile is sourced and `npx` is not on PATH — six installs failed together this way.
- **`npx` inside `find | while read` eats the loop's stdin.** Collect the list into a variable and iterate with `for`, or redirect the command's stdin from `/dev/null`.
- **Verify functionally, not by file content.** Grepping the installed file proves it arrived; feeding a guard payloads and checking exit codes proves it decides correctly.

### Skills

- **Skills are conffiles.** A modified skill is preserved and the current template is written beside it as `SKILL.md.new`. There is no need to hand-save `/self-check`'s Project-specific Checks before upgrading — that was required before 2.12.2 and is not now. Extra user-authored skill dirs are never touched.
- **Installs that jumped from `<2.12.2` have no manifest**, so retired skills are never removed there and will persist indefinitely.

---

## Compact Supplement

When compacting, preserve:
- Current npm version and what's published vs unpublished
- Which files were changed since last publish
- Any Windows-specific fixes in progress
- The relationship: templates/ = source of truth, .claude/ = local install (dogfood)
