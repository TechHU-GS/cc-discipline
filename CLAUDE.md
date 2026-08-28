# cc-discipline — CLAUDE.md

> General discipline rules are auto-injected via `.claude/rules/`. This file is for project-specific information only.

---

## Project Overview

- **Project name**: cc-discipline
- **One-line description**: Discipline framework for Claude Code — rules, hooks, skills, and agents that keep AI on track
- **Tech stack**: Bash (hooks, init.sh, CLI scripts), Node.js (cli.js cross-platform entry), jq (JSON processing)
- **Key constraints**: Must work on macOS + Linux + Windows (Git Bash). Hooks must be lightweight (<100ms). Total rules context footprint <3% of 200K context.

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
│   │   ├── skills/      ← 6 skills (commit, self-check, evaluate, think, summary, investigate)
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

- **macOS /tmp → /private/tmp**: `cwd` in hook JSON will be `/private/tmp/...`. Use both paths for file checks.
- **npm bin path on Windows**: npm creates `.cmd` shims, bash scripts don't work directly. cli.js solves this.
- **`npx cc-discipline` FAILS inside this repo** — npx resolves the name against the local `package.json`, finds our own name, then looks for a `cc-discipline` bin that was never installed into `node_modules/.bin`, and dies with `'cc-discipline' is not recognized as an internal or external command`. Use `node bin/cli.js upgrade` for the dogfood install. Worse, the failure is easy to mistake for success: it exits with a *message*, so if you pipe the output through a filtering `grep` you see nothing and may conclude "upgrade ran, nothing changed" — always check the version marker at `.claude/.cc-discipline-version` afterwards.
- **`cp -r "$dir/" dest/` means different things on GNU and BSD — never use it.** With a trailing slash on the source, GNU cp copies the *directory*; BSD cp (macOS) copies its *contents*. v2.11.0's "directory-driven" skill install used `for skill_dir in .../skills/*/` (the glob appends the slash) plus `cp -r "$skill_dir" .claude/skills/`, so **on macOS every skill's SKILL.md was written over the previous one at `.claude/skills/SKILL.md` and not one skill was ever installed or updated.** Found 2026-07-30 on all 9 Mac projects: a stray `.claude/skills/SKILL.md` holding `think` (last in the loop), skill dirs frozen at their first-install date, and `/finish` missing everywhere. Fixed in v2.12.1 by copying into an explicit destination (`mkdir -p ".claude/skills/$name"; cp -R "$skill_dir"* ".claude/skills/$name/"`), plus cleanup of the stray file.
  Why it hid: rules/hooks/agents copy **individual files** (`cp file dst/`), which has no GNU/BSD divergence, so they kept updating correctly and the version marker advanced — the install looked healthy. `status`/`doctor` glob `skills/*/`, and a bare file is not a directory, so neither could see it. **Test installs on macOS AND Windows before releasing; a Windows-only test would not have caught this.**
- **`upgrade` silently overwrites customized skills.** `init.sh` installs skills with a plain `cp -r` per template dir, so anything a user filled in gets replaced by the template — notably `/self-check`'s **Project-specific Checks** section, which exists *specifically* to be filled in. Verified on this repo 2026-07-30: two real project checks were wiped by an upgrade. Recoverable (the pre-upgrade `.claude/.backup-<ts>/` holds the old skills) but nothing tells you it happened. **Before upgrading a project that has filled that section, save it and restore afterwards.** Extra user-authored skill dirs are safe — the loop only copies template dirs and never deletes.
- **set -e on Git Bash**: Many commands fail silently on Windows due to path/command differences. Disabled for MINGW/MSYS.
- **jq not always available**: Every hook MUST have grep/sed fallbacks for jq — for EVERY field it reads, not just the obvious one. v2.11.0 fixed `session_id` in action-counter but left five other jq-only reads in place; the v2.12.0 audit found them, and one was severe: **git-guard read `tool_name` with jq only, so on Windows it exited 0 at the first check and every destructive-git guard in the file was dead code from day one** (`git reset --hard`, `git clean -fd`, `git checkout .` all passed silently — verified). post-error-remind was worse than useless: its no-jq path fell back to `OUTPUT="$RAW_INPUT"`, matching error patterns against the whole JSON envelope *including the command text*, so `grep -rn "permission denied" logs/` flagged itself.
  **Guard against recurrence — run this before any release and after touching a hook:**
  ```bash
  # Every jq read must sit inside a `command -v jq` branch that has an else.
  grep -n 'jq -r' templates/.claude/hooks/*.sh
  # Then actually run them with jq absent (this repo's dev box has no jq):
  for f in templates/.claude/hooks/*.sh; do bash -n "$f" || echo "SYNTAX $f"; done
  ```
  Choose the failure direction deliberately and write it in a comment: git-guard fails **loud** (a spurious confirmation costs one turn, a miss costs the user's work); post-error-remind fails **silent** (a false positive misleads).
- **grep -c returns exit 1 on zero matches**: Use `VAR=$(grep -c ...) || VAR=0`, not `grep -c ... || echo "0"`.
- **stat -c BEFORE stat -f — the reverse is broken**: GNU stat (Linux, Windows Git Bash) uses `stat -c %Y`; BSD stat (macOS) uses `stat -f %m`. Order matters and is NOT symmetric: in GNU stat `-f` is not BSD's "format" flag, it means *show filesystem status* — so `stat -f %m file` SUCCEEDS on Git Bash and prints a multi-line filesystem dump, which means a `stat -f ... || stat -c ...` chain never reaches the fallback and the caller then does arithmetic on that dump. That is exactly what shipped: action-counter's progress.md staleness check spewed `syntax error in expression` on every 50th action on Windows and never worked there. `stat -c` on macOS is simply an invalid option, so it fails cleanly. Always try `-c` first, and validate the result is a bare integer (`case "$V" in ''|*[!0-9]*) V="" ;; esac`) before arithmetic. Fixed v2.12.0.
- **Version must be bumped in package.json only**: init.sh reads from package.json via cli.js env var. No hardcoded versions.
- **CRLF on Windows → macOS breakage**: `.gitattributes` forces `eol=lf` for .sh/.md/.json **and .js**. `.js` was added 2026-07-30 after nearly shipping a broken 2.12.0: `bin/cli.js` is the npm `bin` target, so on macOS/Linux npm runs it via its shebang, and a CRLF file leaves a stray CR after `node` → `env: node: No such file or directory`. The CLI works fine as `node bin/cli.js` either way, which is why this hides.
  **Two things that make this easy to miss — check both:**
  - **`npm publish` packs the WORKING TREE, not git.** Git had `cli.js` as LF the whole time; only the Windows checkout was CRLF (`.gitattributes` didn't cover `.js`). A clean `git show` proves nothing about what ships.
  - Verify with a scan that includes `.js`, not just `file init.sh`:
    ```bash
    find . -name node_modules -prune -o -name .git -prune -o -type f \
      \( -name '*.sh' -o -name '*.md' -o -name '*.json' -o -name '*.js' \) -print \
      | xargs file | grep CR
    ```
    Must print nothing. Check the shebang specifically with `head -1 bin/cli.js | cat -A` — it must end `node$`, not `node^M$`.
- **`printf` in bash eats one backslash level — twice**: `printf 'a\\nb'` emits a REAL newline, and `printf 'x\\r'` emits a REAL carriage return. Writing a doc comment *about* `\r` this way silently injected a CR into `.gitattributes` (caught with `cat -A`). To emit a literal backslash sequence use `awk 'BEGIN{printf "a%cn", 92}'`, or just rephrase to avoid the escape. Same trap when building hook test payloads — see docs/progress.md Gotchas.
- **`grep '\*\.js'` matches `*.json`**: guarding an append to `.gitattributes` with that pattern silently skipped the append. Anchor it: `grep -qE '^\*\.js[[:space:]]'`.

---

## Compact Supplement

When compacting, preserve:
- Current npm version and what's published vs unpublished
- Which files were changed since last publish
- Any Windows-specific fixes in progress
- The relationship: templates/ = source of truth, .claude/ = local install (dogfood)
