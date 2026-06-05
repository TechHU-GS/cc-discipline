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
│   │   ├── skills/      ← 8 skills (commit, self-check, evaluate, think, retro, summary, investigate, finish)
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
- **set -e on Git Bash**: Many commands fail silently on Windows due to path/command differences. Disabled for MINGW/MSYS.
- **jq not always available**: Every hook MUST have grep/sed fallbacks for jq. Watch `session_id` especially — action-counter shipped jq-only through v2.10.x, so on Windows (no jq) every session collapsed to the literal `"unknown"` and shared one never-resetting global counter (it had climbed to 13065), silently killing the early-action phase check. Fixed v2.11.0 by mirroring streak-breaker's `jq`-or-`grep` pattern. When adding/editing a hook, smoke-test it with jq absent.
- **grep -c returns exit 1 on zero matches**: Use `VAR=$(grep -c ...) || VAR=0`, not `grep -c ... || echo "0"`.
- **stat -f vs stat -c**: macOS uses `stat -f %m`, Linux uses `stat -c %Y`. action-counter tries both.
- **Version must be bumped in package.json only**: init.sh reads from package.json via cli.js env var. No hardcoded versions.
- **CRLF on Windows → macOS breakage**: `.gitattributes` forces `eol=lf` for .sh/.md/.json. Before npm publish, verify with `file init.sh` — must NOT show "with CRLF line terminators".

---

## Compact Supplement

When compacting, preserve:
- Current npm version and what's published vs unpublished
- Which files were changed since last publish
- Any Windows-specific fixes in progress
- The relationship: templates/ = source of truth, .claude/ = local install (dogfood)
