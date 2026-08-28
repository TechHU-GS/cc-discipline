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

Seven shell scripts run automatically before and after Claude's actions. Two of them can stop an operation outright — `git-guard.sh` on destructive git commands, and `streak-breaker.sh` once a file passes its edit ceiling. The rest inject context rather than block. The three below are the ones worth seeing in action:

**`streak-breaker.sh`** — Tracks per-file edit counts. Source files warn at 6 and **hard-block at 10**; config and docs warn at 10 and block at 16. Confirming that a run of edits is planned doubles both thresholds for that file. Forces Claude to stop and find the root cause instead of endlessly patching.

> Raised from 3/5 on 2026-07-30. Newer models complete multi-file features end to end rather than one pass per file, so five edits to one source file is now common in legitimate work — the old thresholds fired on progress, not on circling.

Here's what it looks like in practice:

```
You:   "Fix the login validation bug in auth.py"

Claude: I'll fix the validation logic.
        [Edit src/auth.py — fix email regex]

Claude: The regex wasn't enough, let me also add length check.
        [Edit src/auth.py — add input length validation]

Claude: That broke the existing tests, let me adjust.
        [Edit src/auth.py — fix test compatibility]
        ⚠️ EDIT NOTE: File src/auth.py has been edited 6 times.
        Quick check: are these edits building toward a goal,
        or fixing previous edits?

Claude: Let me try a different approach to the validation.
        [Edit src/auth.py — rewrite validation layer]
        [… three more edits …]

Claude: Almost there, one more adjustment...
        [Edit src/auth.py — blocked]

        🛑 EDIT CHECKPOINT
        File src/auth.py has been edited 10 times this session.
        Reflect:
          1. Are these edits progressing toward a goal,
             or fixing previous edits?
          2. If fixing previous edits: pause and look
             for the root cause.

Claude: You're right. Looking at all 10 edits, I was patching
        symptoms. The real issue is that the User model's
        validate() method is called before sanitization.
        Let me fix it at the source instead.
```

Without the hook, Claude would keep editing `auth.py` indefinitely — each fix creating the next bug. The hook forces a pause that leads to root-cause discovery.

---

**`pre-edit-guard.sh`** — Before a source edit, checks `docs/debug-log.md` for hypotheses still marked pending, flags unusually large diffs, and reminds you to register newly created scripts. These are context notes, not blocks.

> Downgraded from a hard block on 2026-07-30. Combined with the debugging rules it had become a trap: write three hypotheses into the log as the rules ask, and you were then barred from editing source until three were confirmed — including for unrelated planned work. The hypothesis discipline stays in the rules; only the enforcement was relaxed.

```
You:   "The API is returning 500 errors on /users endpoint"

Claude: Let me investigate.
        [Bash: curl localhost:3000/users]
        → 500 Internal Server Error

Claude: I think it's a database connection issue. Let me fix
        the connection pool config.
        [Edit src/db.py]

        DEBUG-LOG NOTE: docs/debug-log.md has 2 hypotheses
        still marked pending. If this edit is the fix for one
        of them, update its status first so the log stays
        truthful. If this edit is unrelated work, carry on.

Claude: Right, I haven't verified my hypothesis yet.
        Let me check the actual error logs first.
        [Bash: tail -50 logs/error.log]
        → TypeError: Cannot read property 'map' of undefined
           at UserSerializer.format (src/serializers.py:42)

Claude: The error is in the serializer, not the database.
        My first hypothesis was wrong. Let me update
        debug-log.md and then fix the actual issue.
```

Without the hook, Claude would have "fixed" the database config — a perfectly working component — and the real bug would remain.

---

**`post-error-remind.sh`** — Detects error patterns (test failures, crashes, build errors) in command output and injects a debugging discipline reminder before Claude can react impulsively.

```
Claude: Let me run the tests.
        [Bash: pytest tests/]
        → FAILED tests/test_auth.py::test_login - AssertionError
        → 1 failed, 23 passed

        ⚡ Error encountered — debugging checklist:
        1. Resist modifying code immediately
        2. Fully understand the error message
        3. List >=3 possible causes
        4. Only then fix

Claude: Before jumping in, let me understand the failure.
        The test expects a 200 but gets 401. Three possible
        causes:
        1. Token generation changed (check auth.py changes)
        2. Test fixture uses expired mock token
        3. Middleware order changed after recent refactor
        Let me verify each...
```

Without the hook, Claude's instinct is to immediately open the test or source file and start editing. The reminder forces a diagnostic pause.

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
WARN_THRESHOLD=6     # Warn after N edits to same source file
STOP_THRESHOLD=10    # Hard block after N edits
# Config and doc files use 10/16; a confirmed run doubles both
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
