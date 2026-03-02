# cc-discipline

Guardrails for Claude Code. Shell hooks that **actually block** bad behavior, not just markdown that asks nicely.

[中文文档](README.zh-CN.md)

## The Problem

Claude Code in long sessions tends to:
- Edit the same file 5+ times chasing symptoms instead of finding root cause
- See an error and immediately change code without understanding it
- Lose track of what it was doing after context compaction

Markdown rules help, but Claude can ignore them. **Hooks can't be ignored** — they run as shell scripts and `exit 2` physically blocks the operation.

## What This Does

### Hooks (the enforcer)

Three shell scripts that run automatically before/after Claude's actions:

**`streak-breaker.sh`** — Tracks per-file edit counts. Warns at 3, **hard-blocks at 5**. Forces Claude to stop and find the root cause instead of endlessly patching.

```
MOLE-WHACKING ALERT (hard stop)
File src/auth.py has been edited 5 times.
You are repeatedly patching symptoms instead of solving the root cause.
Required actions:
  1. Stop editing this file immediately
  2. Review the purpose of all 5 edits
  3. Look for the common root cause
  4. Report findings to the user and wait for guidance
```

**`pre-edit-guard.sh`** — Checks `docs/debug-log.md` for unverified hypotheses. If you're debugging and haven't finished the process, it blocks source code edits until you do.

**`post-error-remind.sh`** — Detects error patterns (test failures, crashes, build errors) in command output and injects a debugging discipline reminder before Claude can react impulsively.

### Rules (the reminders)

Auto-injected markdown in `.claude/rules/` — Claude sees them when operating on matching files. Not as strong as hooks, but provides structure:

- Debugging process: gather → hypothesize → verify → fix (no skipping)
- Pre-edit checklist: understand the file, know the impact, fix root cause
- Mole-whacking detection: recognize the pattern, stop, report
- Phase discipline: stay in research/plan/implement, don't jump ahead
- Multi-task gates: complete tasks in order, confirm each before moving on
- Tech stack rules for Python, JS/TS, embedded, RTL, mobile

### Subagents (the auditors)

- **reviewer** — Reviews your modification plan in a separate context. Challenges assumptions, suggests alternatives, checks for missing edge cases.
- **investigator** — Researches the codebase in isolation. Returns structured findings without polluting your main conversation.

## Install

```bash
git clone https://github.com/TechHU-GS/cc-discipline.git ~/.cc-discipline
cd your-project
bash ~/.cc-discipline/init.sh
```

The installer is interactive — pick your tech stack, name your project, done.

**Already have a `.claude/` setup?** The installer detects this and runs in append mode:
- Your `CLAUDE.md` is **never overwritten**
- Your `settings.json` hooks are **preserved** (cc-discipline hooks are merged in via `jq`)
- Your custom rules, agents, and docs are **untouched**
- A timestamped backup is created before any changes

**Upgrading?** Just run `init.sh` again. It detects the existing installation and updates framework files while preserving your configuration.

## What Gets Installed

```
.claude/
├── rules/                    # Auto-injected when Claude operates on matching files
│   ├── 00-core-principles.md
│   ├── 01-debugging.md
│   ├── 02-before-edit.md
│   ├── 03-context-mgmt.md
│   ├── 04-no-mole-whacking.md
│   ├── 05-phase-discipline.md
│   ├── 06-multi-task.md
│   └── stacks/               # Picked during install
├── hooks/                    # Shell scripts, exit 2 = block operation
│   ├── streak-breaker.sh
│   ├── pre-edit-guard.sh
│   └── post-error-remind.sh
├── agents/
│   ├── reviewer.md
│   └── investigator.md
├── skills/
│   └── commit/SKILL.md       # /commit: test → update docs → commit
└── settings.json             # Hook registration
docs/
├── progress.md               # Claude maintains this, read after compact
└── debug-log.md              # Debug session tracking
CLAUDE.md                     # Your project info (you fill this in)
```

## Customization

**Adjust hook strictness:**

```bash
# In .claude/hooks/streak-breaker.sh
WARN_THRESHOLD=3    # Warn after N edits to same file
STOP_THRESHOLD=5    # Hard block after N edits
```

**Add your own rules:**

```bash
cat > .claude/rules/my-rule.md << 'EOF'
---
globs: "src/api/**/*"
description: "API layer rules"
---
- All API changes must be backwards-compatible
- New endpoints need OpenAPI spec updates
EOF
```

**Write your own hooks:**

Any script in `.claude/hooks/` can be registered in `settings.json`. The key behaviors:
- `exit 0` = allow (stdout can inject context via JSON for PreToolUse hooks)
- `exit 2` + stderr = block operation, stderr message shown to Claude

See [Claude Code hooks docs](https://docs.anthropic.com/en/docs/claude-code/hooks) for the full spec.

## FAQ

**Is this just markdown rules?**
No. The hooks are the real enforcement — they're shell scripts that physically block operations. The rules are supplementary structure.

**Does it slow things down?**
No. Hooks are lightweight shell scripts, typically <100ms. Rules add ~8KB to context (~2%).

**Should I commit `.claude/` to git?**
Yes. Team members get the same guardrails. Hook paths use `$CLAUDE_PROJECT_DIR`, so they work across machines.

**Does it work with existing projects?**
Yes. The installer has an append mode that merges with your existing `.claude/` configuration without overwriting anything. Run `init.sh` and it auto-detects.

## Contributing

PRs welcome — especially new hooks. The hooks are where the real value is.

## License

[MIT](LICENSE)
