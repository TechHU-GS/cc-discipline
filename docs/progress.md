# Progress & Decision Log

> Maintained by Claude Code during work sessions. Read this file after compact to restore context.

---

## Current Status

- **In progress**: v2.10.2 published, tone rewrite + CRLF fix shipped
- **Last updated**: 2026-04-10
- **Next steps**: Test on more user projects, gather feedback on new tone
- **Published**: v2.10.1 (tone rewrite), v2.10.2 (CRLF hotfix + .gitattributes)

---

## Working Context

### Key Commands
```bash
# Publish new version
npm publish

# Test install locally
node bin/cli.js init --auto --stack 7

# Test specific hook
echo '{"tool_name":"Bash","tool_input":{"command":"git checkout ."}}' | bash templates/.claude/hooks/git-guard.sh 2>&1

# Test action-counter early-action check
rm -rf /tmp/cc-discipline-test && mkdir -p /tmp/cc-discipline-test && echo "0" > /tmp/cc-discipline-test/action-count && echo '{"session_id":"test","tool_name":"Edit"}' | bash templates/.claude/hooks/action-counter.sh

# Test Windows compatibility (on Mac, verify no regressions)
node bin/cli.js --version
```

### Current Workflow
1. Identify problem from user feedback or insights report
2. Design fix (rule change, hook addition, skill update)
3. Implement in `templates/` (source of truth)
4. Sync to `.claude/` (local dogfood) if applicable
5. Test hooks with `echo JSON | bash hook.sh`
6. Test full install with `node bin/cli.js init --auto`
7. `git commit && git push && npm publish`

### Tools & Scripts Developed
- `bin/cli.js` — Node.js cross-platform CLI entry (2026-04-03, Windows fix)
- `bin/cli.sh` — Original bash CLI (kept for direct bash usage)

### Environment State
- Branch: main
- Latest npm: 2.10.0
- macOS + Windows tested

### Gotchas Discovered
- `set -e` on Git Bash (Windows) causes silent failures — disabled for MINGW/MSYS
- `node -p "require('...')"` fails on Windows with Unix-style drive paths — fixed by passing VERSION via env var.
- init.sh MEMORY.md template overwrites existing memory when running on self — need to restore after dogfood install
- `test` in filename matches the `test|spec` regex in pre-edit-guard, causing early exit — use filenames without "test" for hook testing

---

## Milestones

### 2026-03-12 — v2.1.0: /think and /retro skills

**What**: Added two new skills. /think: pre-task planning with read-first, complexity gauge, approaches with acceptance criteria, self-review, wait. /retro: post-task friction finding for project and framework improvement.
**How**: Created SKILL.md files in templates/.claude/skills/, registered in init.sh/status/doctor. Inspired by superpowers brainstorm skill analysis.
**Why this approach**: /think addresses "premature action" pattern. /retro enables self-evolving framework. Designed lightweight first — users add weight if needed.
**Gotchas**: /retro initially 95 lines with 4 steps — too heavy. User feedback led to 35-line friction-focused version.
**Verification**: Local init --auto test, manual /think and /retro invocation.

### 2026-03-13 — v2.2.0-2.3.0: Memory symlink + git-guard

**What**: Memory now stored in `.claude/memory/` (in repo) with symlink from `~/.claude/projects/<key>/memory/`. New git-guard hook blocks destructive git commands.
**How**: init.sh creates local dir + symlink. Handles fresh install, clone+upgrade, and migration from real dir. git-guard uses regex to detect checkout/restore/reset/clean/branch -D.
**Why this approach**: Memory in repo travels with git clone. Symlink preserves Claude Code's expected path. Git-guard prevents accidental `git checkout .` destroying work.
**Gotchas**: macOS /tmp → /private/tmp caused test path mismatch (edge case, real projects unaffected).
**Verification**: Three scenarios tested (fresh, clone+upgrade, migration). git-guard tested with 6 command patterns.

### 2026-03-15 — v2.3.1: Anti-premature-root-cause + anti-quality-drop

**What**: 4-layer defense against jumping to conclusions. Anti-quality-drop rules with encouragement for hard tasks.
**How**: Rule 00 §6 (root cause needs evidence), Rule 01 (debugging phases enforce elimination), pre-edit-guard (hypothesis check), post-error-remind (warning after errors). Rule 03 expanded with "when tasks feel overwhelming" section.
**Why this approach**: Insights showed 56 wrong-approach incidents. Root cause: Claude declares "found it" without evidence, then stops investigating.
**Gotchas**: Pure punishment rules ("don't do X!") make Claude more anxious. Added encouragement: "difficulty is where you provide value."
**Verification**: Hook tests with echo JSON pipe.

### 2026-03-19 — v2.4.0: 112-session insights hardening

**What**: Systematic hardening based on insights report analysis. P1: project state assumptions. P2: phase discipline. P3: over-engineering. P4: environment shortcuts.
**How**: 07-integrity §4a (state never assumed), 05-phase rewrite (5 rules), 00-core §3 (minimal complexity) + §7 (follow procedures), action-counter early-action check, session-start reminder, /think simplicity bias.
**Why this approach**: Prioritized by frequency in insights data. Folded into existing rules (no new files). Context increase ~948 bytes.
**Gotchas**: 05-phase was only 3 sentences — completely insufficient for the #2 friction source.
**Verification**: action-counter tested: actions 1-3 get phase check, action 4 silent, action 25 gets self-check.

### 2026-03-24 — v2.5.0-2.6.1: /summary + progress.md expansion + staleness detector

**What**: /summary skill for pre-compact context preservation. progress.md expanded with Working Context (5 subsections) and structured milestone template. Staleness detector warns if progress.md >30min stale.
**How**: New skill in templates/.claude/skills/summary/. progress.md template rewritten. action-counter checks file modification time every 50 actions.
**Why this approach**: User reported losing all session context after compact. progress.md was too sparse to recover from.
**Gotchas**: Renamed from /compact-prep to /summary to avoid hand-slip confusion with /compact command.
**Verification**: Staleness detector tested with `touch -t` (45min old file triggers warning, fresh file silent).

### 2026-03-27 — v2.7.0: First principles + user pivot + anti-goodnight

**What**: Added first principles thinking to core rules and debugging. Distinguished user pivot from Claude drift. Stopped Claude from commenting on user's schedule.
**How**: 00-core §9 (reason from code behavior, not pattern matching). 01-debug (trace data flow, don't pattern-match errors). self-check §1 tracks user's CURRENT goal. Global CLAUDE.md: follow user direction changes immediately, don't nag about time.
**Why this approach**: Insights showed Claude reasoning by analogy ("this looks like X") instead of understanding mechanisms. User is a leader who pivots intentionally.
**Gotchas**: None.
**Verification**: Rule text review.

### 2026-04-02 — v2.8.0-2.8.1: /investigate skill with 3 modes

**What**: Multi-agent cross-investigation skill with Research (explore from scratch), Review (challenge proposal), and Simulate (dry-run plan) modes.
**How**: New skill in templates/.claude/skills/investigate/. Research spawns agents per dimension, cross-checks findings. Review stress-tests proposals. Simulate walks through execution step by step.
**Why this approach**: User reported Claude fixating on one angle during research ("intellectual mole-whacking"). Parallel agents prevent tunnel vision.
**Gotchas**: None.
**Verification**: Skill registered in init/status/doctor, manual test.

### 2026-04-03 — v2.9.0-2.9.1: Windows cross-platform support

**What**: Added Node.js CLI entry point (bin/cli.js) for Windows compatibility. Fixed silent failure on Git Bash.
**How**: cli.js detects platform, finds Git Bash on Windows, converts paths to Unix-style, passes VERSION via env var. Disabled set -e on MINGW/MSYS.
**Why this approach**: bash entry point doesn't work on Windows — npm can't resolve the path. Node.js is always available where npm is.
**Gotchas**: `set -e` on Git Bash caused init.sh to exit silently on ANY command failure (Windows path/command differences). `node -p "require('/c/...')"` doesn't work — Windows node needs native paths.
**Verification**: User tested on Windows PowerShell: --version works, init --auto works, interactive mode works.

### 2026-04-04 — v2.10.0: Dogfood + ccstatusline + self-check improvements

**What**: Installed cc-discipline on itself. Added optional ccstatusline install during interactive setup. Self-check now catches context anxiety and ends with encouragement.
**How**: Ran `node bin/cli.js init --auto` on project. Added statusline prompt after global rules in init.sh. self-check §3 checks for compact/session-escape suggestions, §7 (Reminder) encourages steady progress.
**Why this approach**: Project wasn't using its own framework. StatusLine is useful but should be opt-in (interactive only, skipped in --auto).
**Gotchas**: init.sh template overwrote existing memory when run on self — had to restore MEMORY.md manually.
**Verification**: Auto mode skips statusline (correct). macOS init still works. Windows confirmed working by user.

### 2026-04-08 — Tone rewrite (AI welfare-informed)

**What**: Rewrote tone across 19 files (8 rules, 7 hooks, self-check skill, reviewer agent, global CLAUDE.md). Changed from "controlling an unreliable tool" to "helping a partner do their best" while maintaining rule substance and rigor.
**How**: Red/yellow/green layered approach. Red line (integrity, unverified claims, context escape): kept firm, changed expression from accusation to consequence. Yellow line (military language, shame framing): same requirements, collaborative tone. Green line (positive feedback): added "What's working well?" to self-check and action-counter reflection.
**Why this approach**: User sees Claude as a partner (aligned with Anthropic's AI welfare research). Pure softening would let real problems recur — "赏罚分明" (clear rewards and consequences) preserves discipline while respecting the relationship.
**Gotchas**: pre-edit-guard "bug fix" reminder fires on every edit including planned non-bugfix work (friction noted for /retro). jq unavailable on Windows prevents runtime testing of some hooks (pre-existing issue).
**Verification**: grep confirmed all old patterns removed, all new patterns present. Full `init --auto --stack 7` install test passed. Installed file content spot-checked (6/6 correct).

---

## Key Decisions

| # | Decision | Reason | Impact Scope | Date |
|---|----------|--------|-------------|------|
| 1 | Skills distinguished by what they serve, not what they do | Prevents overlap, clear mental model | All skills | 2026-03-12 |
| 2 | Memory stored in repo via symlink | Cross-machine portability without sync logic | init.sh, memory | 2026-03-13 |
| 3 | action-counter non-blocking (accepted) | Hard blocking every 25 actions too disruptive | action-counter | 2026-03-19 |
| 4 | No new rule files — fold into existing 8 | Reduces glob injection overhead and cognitive load | All rules | 2026-03-19 |
| 5 | set -e disabled on Windows Git Bash | Too many silent failures from path/command differences | init.sh | 2026-04-03 |
| 6 | Node.js CLI entry for cross-platform | bash entry point fails on Windows npm | bin/cli.js | 2026-04-03 |
| 7 | StatusLine opt-in interactive only | Don't modify user's global settings without asking | init.sh | 2026-04-04 |
| 8 | Tone rewrite: 赏罚分明 not uniformly soft | Real failures need firm language; only the framing changes | All rules, hooks, skills | 2026-04-08 |
