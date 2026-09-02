# Progress & Decision Log

> Maintained by Claude Code during work sessions. Read this file after compact to restore context.

---

## Current Status

- **Committed, NOT yet published**: **v2.13.4** — `/coplan` reworked from a four-response usage survey (2.13.3, also unpublished, made its plan file untracked). See the 2026-09-02 entry.
- **Published**: **v2.13.2**, rolled out to all 22 installs. Three releases in one pass — 2.13.0 retired `/finish` and `/retro` and added `/coplan`; 2.13.1 and 2.13.2 fixed two CRLF defects that the rollout itself exposed.
- **Fleet: 22 installs on 3 machines, all v2.13.2** — MS-01 (10), mac-mini-m4 `techhu@100.64.0.8` (5), techhu-7940 `techhu_dev@100.64.0.18` (7). Verified by scanning for `.claude/hooks/streak-breaker.sh`, **not** by the version file: three installs (`phenology-twin`, `soil-twin`, `vini-twin`) predate 2.0.0, carry no version file, and had been invisible to every previous rollout. The hardcoded seven-project list used since July was stale.
- **Last updated**: 2026-08-30
- **Skills are now 7**: commit, coplan, evaluate, investigate, self-check, summary, think.
- **Next steps**:
  1. **npm token rotation** — pasted in chat 2026-06-05, still not rotated. Highest severity item and the only one the user must do personally: it can publish arbitrary code under this package name, which 22 projects pull via `npx cc-discipline@latest`.
  2. **Hook latency**: the three hooks firing on every edit total **1,267 ms** on Windows/Git Bash against the `<100ms` claimed in CLAUDE.md:12. Root cause is 65 subprocess calls at 20-30 ms each. Deliberately deferred — it refactors the parsing core of the only enforcement layer and needs its own pass with before/after numbers on both platforms.
  3. **Pre-2.12.2 installs never retire skills.** Those upgraded straight from `<2.12.2` to 2.13.x have no manifest, so the conservative "no manifest, remove nothing" rule leaves `/finish` and `/retro` in place forever (seen on `HUB_Rev1_FW`). Fixing needs a shipped list of historical digests for the retired skills — a one-time special case, not yet decided.
  4. **`AGENTS.md`: decided against** for these repos (2026-08-30, see the milestone at the end). It sits downstream of the sandbox gate and cannot affect write permission; the criterion is whether Codex actually modifies files, and today it only reviews. Revisit the day Codex is given `--write` to implement something.
  5. Frozen rule bucket (`00` §6, `01-debugging`, `05-phase`, `07` §4a) still undecided — rules leave no mechanical trace, so the transcript sweep that settled the hooks cannot settle these.
- **Published**: v2.10.1 … v2.12.3, v2.13.0 (retired /finish + /retro, added /coplan), v2.13.1 (manifest line-ending normalization), v2.13.2 (manifest file itself protected)

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

# git-guard regression matrix — MANDATORY after any git-guard matching change
bash tests/git-guard-matrix.sh                              # templates/ copy
bash tests/git-guard-matrix.sh .claude/hooks/git-guard.sh   # installed copy

# Audit that every jq read has a non-jq fallback (5 shipped broken before this)
grep -n 'jq -r' templates/.claude/hooks/*.sh

# Fresh-install check — via cli.js, NOT bash init.sh (see self-check notes)
T=$(mktemp -d) && cd "$T" && git init -q &&   CC_DISCIPLINE_PKG_DIR=/e/Code/cc-discipline node /e/Code/cc-discipline/bin/cli.js init --auto --stack 7
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
- `tests/git-guard-matrix.sh` — 25-case regression matrix for git-guard (2026-07-30). Must-block / must-pass / safe-commands. Run after ANY git-guard matching change; verified 25/25 on GNU sed (MS-01, 7940) and BSD sed (mac-mini). Not shipped to npm.

### Environment State
- Branch: main
- **3 machines, 22 installs, all v2.12.3.** MS-01 = this box (Windows, no jq, `E:\Code`). Remotes over Tailscale, passwordless SSH from here:
  - `techhu@100.64.0.8` mac-mini-m4 — macOS, HAS jq, node at `/usr/local/bin` (use `bash -lc` over SSH or PATH is missing it), code in `~/Code`
  - `techhu_dev@100.64.0.18` techhu-7940 — Windows, node v24, code in `D:/Code`, cmd.exe shell. `bash` on PATH is only the WindowsApps WSL stub (wrong filesystem view); for Git Bash call its full path under `Program Files/Git/bin/` quoted, and note Git Bash sees the code dir as `/d/Code`.
- Full machine details live in `techhu-devices/.claude/skills/dev-machines/SKILL.md`
- Latest npm: 2.12.3 published (2026-07-30). macOS + Windows both tested before publish — see v2.12.1 milestone for why that is now mandatory.
- macOS + Windows tested

### Gotchas Discovered
- `set -e` on Git Bash (Windows) causes silent failures — disabled for MINGW/MSYS
- `node -p "require('...')"` fails on Windows with Unix-style drive paths — fixed by passing VERSION via env var.
- init.sh MEMORY.md template overwrites existing memory when running on self — need to restore after dogfood install
- `test` in filename matches the `test|spec` regex in pre-edit-guard, causing early exit — use filenames without "test" for hook testing
- **Building hook test payloads**: `printf 'line\\n'` in bash emits a REAL newline, not the two-char `\n` that real hook JSON contains. Malformed payloads make working hooks look broken. Use `awk 'BEGIN{printf "line%cn", 92}'` (92 = backslash) to get a literal `\n`. Same trap bit twice in one session: writing a `.gitattributes` comment *about* `\r` via `printf` injected a real carriage return into the file. Always `cat -A` after a printf that contains backslashes.
- **`grep '\*\.js'` matches `*.json`** — a guard against duplicate-appending `*.js` to `.gitattributes` silently did nothing. Anchor patterns like this: `grep -qE '^\*\.js[[:space:]]'`.
- **`.md`/`.json`/`.yaml` files early-exit pre-edit-guard** (config-exempt) before the large-diff check — don't use `CLAUDE.md` to test large-diff behaviour; use an existing `.py`/`.sh`.
- **Rules `00` and `07` carry YAML frontmatter, the other six don't.** CLAUDE.md rule injection strips frontmatter, so it is invisible when reading rules through injected context — check the file on disk before assuming a rule starts at `## `.
- **git-guard matches command TEXT**, so any command that merely quotes a destructive git command trips it — including CLAUDE.md's own documented hook-test command. There is a narrow exemption for commands piping into `hooks/*.sh`; extend that rather than weakening the patterns.
- **This dev box has no `jq`** (`command -v jq` → absent). That is a feature for testing: hooks can be exercised on their real Windows no-jq path directly, no sandbox needed.

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

### 2026-06-05 — v2.11.0: /finish skill + /think wiring + self-check friction fix

**What**: (1) New `/finish` skill — drive a task to completion with a quality bar (扎实/全面/完备测试 + 07-integrity verify-before-done). Standalone, or as the handoff after `/think and finish`. (2) /think gained a "Downstream" section documenting `and plan` / `and finish` directives (doesn't touch Steps 0-5; honors phase-discipline — handoff is post-approval only). (3) self-check §5/§8: stale progress.md is now updated **silently and automatically** instead of asking the user each time. (4) self-check frontmatter gains `disallowed-tools: AskUserQuestion` — verified supported in CC 2.1.154 (binary grep + official docs) — so under `/loop` it *physically cannot* stop to ask; hardens (3) from soft instruction to hard guarantee. (/finish deliberately excluded — its Step 1 legitimately asks one round when standalone scope is unclear.)
**How**: Created `skills/finish/SKILL.md` in templates/ + local .claude/. Appended Downstream section to think (both copies). Edited self-check §5 ("update now, automatically — don't ask") and §8 (carve progress.md updates out of "issues" that require a pause). Registered: CLAUDE.md 7→8 skills, local MEMORY.md skills list + design-principle line, package.json 2.10.3→2.11.0.
**Why this approach**: User uses native /goal heavily and wanted a quality-bar'd version. Chose composition (independent skill + /think wiring) over integration — keeps /think pure, allows standalone "想好就直接做" use, and the compositional `and finish` declares post-approval execution stance without bypassing the 05-phase gate. self-check fix: updating progress.md is always-correct maintenance, not a decision needing sign-off — asking every time was pure friction (worse under /loop).
**Gotchas**: `.claude/memory/` is gitignored (symlink, decision #2) so repo greps don't scan it — had to edit the local MEMORY.md directly. /think and /finish are deliberate opposites (align+wait vs drive+done). **init.sh/status.sh/doctor.sh enumerate skills by name** — a new skill must be registered in all three or it won't install. Also two MEMORY.md count refs + one in "Key File Structure" (3 total) were easy to miss; a grep sweep caught the third.
**Verification**: Fresh `init.sh --auto --stack 7` into temp dir → exit 0, `finish/SKILL.md` copied, `doctor` shows `✓ /finish`, `status` reads `8/8 (... /finish)`. Repo sweep for stale "7 skills" refs: clean. `node bin/cli.js --version` → 2.11.0. All edits grep-confirmed in both templates/ and local .claude/ copies.

### 2026-06-05 — v2.11.0 (cont.): framework hardening (soundness review, red items #1–#3)

**What**: (#1) Made skill install/list **directory-driven** instead of name-enumerated. (#2) Removed pre-edit-guard's unconditional per-edit "bug fix" reminder.
**How**: #1 — `init.sh` install loop now globs `templates/.claude/skills/*/` (was 8 hardcoded `cp` lines); the two post-install summary blocks collapsed to one line pointing at `status`; `lib/status.sh` and `lib/doctor.sh` now glob `.claude/skills/*/` (dropped the hardcoded `/8` denominator and the per-name lists). #2 — pre-edit-guard's tail block (lines 93-100) replaced with a silent `exit 0` in both templates/ + local copies.
**Why this approach**: #1 — adding `/finish` this session forced edits in 6 enumerated spots and a grep sweep still found a 3rd stale count; enumeration was accidental coupling where a miss = skill not installed. Now adding a skill = drop a dir, zero script edits. #2 — the reminder fired on *every* non-md/test edit (incl. all of this session's feature/registration work); its guidance is already in always-injected rules 00§6/01 + the hard debug-log block + post-error-remind, so per-edit re-injection was pure noise (it doesn't earn its context footprint).
**Gotchas**: doctor no longer warns about "missing" individual skills (skills are optional/independent, so a missing one isn't an install failure) — acceptable trade. Verified with jq absent (Windows-safe path).
**Verification**: Fresh install → loop copies all 8 skills; `status` reads `8 (/commit … /finish)` (no `/8`); `doctor` lists all 8 via glob. pre-edit-guard fed a `.sh` Edit JSON → empty output, exit 0 (silent). All with `jq` unavailable.

**Plus #3 (action-counter session_id bug — root cause, evidence-backed):** Counter lived at `/tmp/cc-discipline-unknown/action-count` = 13065 (one global, never-resetting tally) because action-counter extracted `session_id` with **jq only, no grep fallback** → on jq-less machines (Windows) every session collapsed to the literal `"unknown"`. Evidence ruling out alternatives: streak-breaker has the grep fallback and its `/tmp` dirs are all real UUIDs (never `unknown-session`), proving `session_id` IS in the input and grep extracts it. Effect of the bug: the early-action phase check (`count<=3`) never fired again after the first-ever session, and the periodic reflection fired off a global tally. **Fix**: copied streak-breaker's jq-or-grep pattern into action-counter (both copies). **Verified**: feeding `{"session_id":"X",...}` → counts land in `/tmp/cc-discipline-X/` starting at 1; the count<=3 phase check was observed firing **live in this session** right after the fix (the dead feature revived). The "reflection fires too often" symptom was a *consequence* of the global counter — per-session counting resolves it; any further trimming of the 10-point block / 25 interval is now optional tuning (deferred to user).

---

### 2026-07-30 — v2.12.0/2.12.1: Opus 5 adaptation audit + 6 platform bugs

**What**: Audited all 33 framework artifacts against Anthropic's official Opus 5 guidance, then applied a split cleanup. Found and fixed 4 pre-existing platform bugs that were more serious than the adaptation issue itself.

**How** — the 4 bugs (all verified by running the hooks with `jq` absent, which is this dev box's real state):
1. **git-guard was entirely dead on Windows.** It read `tool_name` with jq only; with no jq that yielded `""`, so `[ "$TOOL_NAME" != "Bash" ]` was true and the script exited 0 at line 9 — every destructive-git guard below it was unreachable. `git reset --hard`, `git clean -fd`, `git checkout .` all passed silently. Fixed with a jq-or-sed branch; the tool_name gate now only applies when tool_name actually resolved. 13/13 regression cases pass.
2. **post-error-remind matched the whole JSON envelope.** Its no-jq path did `OUTPUT="$RAW_INPUT"`, and the command text lives in that envelope — so `grep -rn "permission denied" logs/` flagged itself. It also couldn't skip non-Bash tools (jq-only tool_name). Fired 3× on this session's own audit commands. Now extracts `.error`/`.output` via sed and **exits 0 if it can't isolate them** (false positives mislead, so silence is the safe direction here — the opposite choice from git-guard, which fails loud). 10/10 cases pass.
3. **`stat -f` before `stat -c` is backwards.** In GNU stat (Linux, Git Bash) `-f` is not BSD's format flag — it means "show filesystem status", so it *succeeds* and prints a multi-line dump, meaning the `||` fallback never ran and the caller did arithmetic on the dump. action-counter's progress.md staleness check emitted `syntax error in expression` every 50th action and never worked on Windows. Reversed to `-c` first + a bare-integer guard.
4. **Two silently-dead detections**: pre-edit-guard's new-script reminder (jq-only tool_name) and its large-diff warning (jq-only, *and* it read only `new_string`, so a large `Write` — which sends `content` — never triggered it even with jq).
5. **`bin/cli.js` had a CRLF shebang — caught by the pre-publish check, one command before publishing.** It is the npm `bin` target, so on macOS/Linux npm runs it through `#!/usr/bin/env node`; the trailing CR makes that `env: node\r: …` → "No such file or directory". Two reasons it hid: the CLI works fine when invoked as `node bin/cli.js` (the shebang is never used), and **git had it as LF all along** — only the Windows checkout was CRLF, because `.gitattributes` covered `.sh/.md/.json` but not `.js`. Since `npm publish` packs the working tree rather than git, a clean `git show` proves nothing. Fixed the file, added `*.js text eol=lf`, and replaced the `file init.sh` spot-check in CLAUDE.md with a repo-wide scan that includes `.js`.

**How** — the cleanup, split by evidence rather than by aggressiveness:
- **Aggressive on hooks** (cheap to revert, per-action cost, and where the officially-condemned patterns live): removed action-counter's 25-action 10-question reflection (~299 tok/firing); cut post-error-remind's ≥3-hypotheses ritual to one line; **downgraded pre-edit-guard's debug-log block from `exit 2` to a note** — as a hard block it combined with 01-debugging Phase 2 into a trap (write 3 hypotheses as instructed → now forbidden from editing source until 3 are confirmed, including for unrelated work); raised streak-breaker 3/5→6/10 (source) and 6/10→10/16 (config); cut session-start's 4 rule restatements, keeping only the skill pointer.
- **Aggressive on unsourced rules**: deleted `02` Post-Edit Checklist, `07` Pre-action Checklist, `03` Parallel Execution (which told Claude to "spawn 3 agents, each verifies one" — Anthropic's guidance forbids this verbatim), softened `00` §1's mandatory narration, and replaced `/think`'s parallel-delegation bullet. All were absent from every prior milestone — added because they sounded like good discipline, not after an observed failure.
- **Conservative on sourced rules — frozen, untouched**: `00` §6 + `01-debugging` (v2.3.1: **56 counted wrong-approach incidents**), `05-phase` + `07` §4a (v2.4.0: **112-session insights, phase discipline was the #2 friction source**), `07` §2/§3/§5, `03`'s encouragement section (v2.3.1: added because punishment-only phrasing measurably raised anxiety), `/investigate`, `/self-check`.

**Why this approach**: Official guidance is a *population-level prior about Opus 5*, not a verdict on our specific rules. Rules written after a measured failure carry local evidence that a prior shouldn't override; rules with no provenance have only the prior, which now points at deletion. The split follows from that, plus a cost asymmetry: hook noise costs tokens (recoverable, instantly visible) while a missing integrity rule costs a false claim reaching the user (not recoverable). Quantified check that settled it: aggressively cleaning *rules* would save **455 tok — 0.045% of a 1M window** — while the per-action hook noise was multiples of the entire rules footprint. The old "<3% of 200K" footprint constraint is now 0.47%; the reason to trim is behavioral interference, not context cost.

**Decisive datum for freezing**: `~/.claude/projects/` holds 501 transcripts. Model distribution: opus-4-8 ×192, opus-4-6 ×91, fable-5 ×56, sonnet-4-6 ×48, haiku-4-5 ×14, opus-4-7 ×9, **opus-5 ×3 — all three dated 2026-07-30, ~2 hours total, including the audit session itself**. The 56-incident/112-session evidence was gathered in March 2026 on Opus 4.6/4.7. So: strong measured evidence about a different model, an official prior about this one, zero local data on this one. Deleting the measured findings now would trade evidence for a prior.

**Measurement gap closed**: `/retro` only ever recorded *friction*, never *saves*. A working rule silently suppresses the failure it was written for, so cost is the only signal that surfaces on its own — judge on cost alone and every rule eventually looks like overhead, including load-bearing ones. Added a `Saves:` section with an explicit "a save is not 'what went well'" bar, plus a `## Rule Ledger` table in progress.md (and the template) that retro appends to each session. This is what makes the frozen bucket decidable with evidence in 2-3 weeks instead of by guess.

**Gotchas**: `printf 'line\\n'` in bash yields a REAL newline, not the two-char `\n` — building test payloads that way silently produced malformed JSON and made the large-diff test look like a hook failure. Use `awk 'BEGIN{printf "line%cn", 92}'`. Also: rules `00` and `07` carry YAML frontmatter (the others don't); CLAUDE.md rule injection strips it, so it's invisible when reading rules through context. And git-guard matches command *text*, so any command quoting a destructive git command trips it — including the hook-test command documented in CLAUDE.md; added a narrow exemption for commands piping into `hooks/*.sh`.

**Verification**: All with `jq` absent. `bash -n` clean on all 7 hooks. git-guard 13/13 (6 destructive blocked incl. newline-separated, 6 safe passed, hook-test exempted). post-error-remind 10/10 (5 silent incl. the exact former false positive, 5 firing incl. `.error` field). action-counter: #1–3 phase check fires, #4 and #25 silent (reflection gone), #50 silent on a fresh file and fires "45min" on a backdated one (staleness check working on Windows for the first time). streak-breaker: #5 silent, #6/#9 warn, #10 blocks. pre-edit-guard: 250-line Edit and 250-line Write both warn, 3-line versions silent, new-script fires. Repo sweep for stale references to removed sections: clean. All `.sh`/`.md` confirmed LF, no CRLF. templates/ and .claude/ byte-identical except skills/self-check (untouched, holds local Project-specific Checks) and rules/stacks (untouched).

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
| 9 | /finish as independent skill + /think wiring (composition, not integration) | Keeps /think pure, allows standalone use, and `and finish` declares post-approval stance without bypassing the 05-phase gate | /finish, /think, init/status/doctor | 2026-06-05 |
| 10 | Cleanup split by **evidence provenance**, not by aggressiveness | Official Opus 5 guidance is a population-level prior; rules written after a measured failure carry local evidence a prior shouldn't override. Rules with no provenance have only the prior — which now says delete | All rules, hooks | 2026-07-30 |
| 11 | Aggressive on hooks, conservative on rules | Cost is in hooks (per-action, multiples of the whole rules footprint); hooks are one-file revertible and their firing is observable, so removals stay attributable. Cleaning rules would save 455 tok = 0.045% of 1M | hooks vs rules | 2026-07-30 |
| 12 | Freeze evidence-backed rules pending Opus 5 data | Only 3 Opus 5 sessions exist (~2h, all 2026-07-30) vs 501 transcripts overall; the 56-incident/112-session basis was gathered on Opus 4.6/4.7 | 00§6, 01, 05, 07§4a, /investigate | 2026-07-30 |
| 13 | Hook failure direction must be chosen per hook and commented | git-guard fails loud (spurious prompt costs a turn, a miss costs the user's work); post-error-remind fails silent (false positives mislead). Same bug class, opposite correct answers | git-guard, post-error-remind | 2026-07-30 |
| 15 | Retire skills on measured usage, not opinion | 397 sessions / 3 machines / 4 weeks: /finish 3 uses, /retro 2, vs /self-check 385. Keeping a skill nobody invokes still costs maintenance and cross-platform testing — the macOS install bug hit all 8, including the two dead ones | skills, init.sh | 2026-08-28 |
| 16 | The ledger write belongs in the skill people actually use | A recording mechanism that depends on being remembered does not run. This is the project's own thesis (instructions get ignored, enforcement does not) applied to itself — the Rule Ledger failed exactly as that thesis predicts | /self-check §7 | 2026-08-28 |
| 14 | Record rule **saves**, not just friction | A working rule suppresses the failure it was written for, so only its cost is naturally observable; cost-only data eventually cuts load-bearing rules | /retro, progress.md Rule Ledger | 2026-07-30 |

---

## Rule Ledger

<!--
Appended by /self-check §7. Two kinds of evidence about the discipline rules themselves:

- SAVE     — a rule or hook changed the outcome: caught a real mistake, blocked a
             real loss, stopped a wrong turn already in motion.
- FRICTION — a rule or hook got in the way and cost time for no benefit.

Why keep this: friction is visible, saves are invisible. A rule that works
silently suppresses the very failure it was written for, so cost is the only
signal that shows up on its own. Judging rules on cost alone eventually cuts the
load-bearing ones. This is the counterweight — with enough dated entries,
"should this rule stay?" becomes a lookup instead of a guess.

Immediate purpose (2026-07-30): decide the frozen bucket — 00 §6, 01-debugging,
05-phase, 07 §4a, /investigate — after 2-3 weeks of real Opus 5 use.
-->

| Date | Kind | Rule / Hook | What happened |
|------|------|-------------|---------------|
| 2026-07-30 | FRICTION | post-error-remind | Fired 3× on this session's own audit commands because the no-jq path matched the whole JSON envelope. Root cause fixed in v2.12.0, not a tuning issue. |
| 2026-07-30 | FRICTION | action-counter reflection | 10-question block fired at #25 and #50 mid-audit; nothing in it was actionable at that moment. Removed in v2.12.0. |
| 2026-07-30 | SAVE + FRICTION | git-guard | **First proof of life since the v2.12.0 fix — and immediately a false positive.** It blocked the commit for this very release, because the commit message *described* the destructive commands it guards against and the guard matches command TEXT. SAVE side: it is demonstrably alive on Windows now, where it had never run. FRICTION side: any command quoting a destructive git command trips it — commit messages, docs, greps. Worked around by `git commit -F <file>` so the command string stayed clean. **Open decision:** `git commit` can never discard working-tree state, but a prefix-based exemption would miss a compound `git commit … && <destructive>`. Options: match only outside quoted arguments, or exempt `-m`/`-F` argument text specifically. Do NOT weaken the destructive patterns themselves. |
| 2026-07-30 | FRICTION | init.sh skills install | Upgrading this repo to 2.12.0 silently overwrote `/self-check`'s Project-specific Checks (2 real project checks — the fresh-install test and the hook smoke-test, i.e. exactly the checks that would have caught this release's bugs). `cp -r` per template dir, no merge. Recoverable from `.claude/.backup-<ts>/` but nothing announces it. → fix: preserve or merge that section on upgrade. |
| 2026-07-30 | FRICTION | npx inside own repo | `npx cc-discipline@2.12.0 upgrade` inside the cc-discipline repo fails (`'cc-discipline' is not recognized…`) because npx resolves the name against the local package.json. It fails with a *message*, so a filtering grep over the output showed nothing and I briefly read it as "ran, nothing changed" — the version marker was the tell. → fix: use `node bin/cli.js upgrade` for dogfood; always verify `.claude/.cc-discipline-version` after an upgrade. |
| 2026-07-30 | SAVE | cross-machine verification | Running the full functional check on the remote machines (not just reading the version marker) caught that **skills had never installed on macOS**. The version marker said 2.12.0 and hooks/rules were genuinely updated, so a marker-only check would have reported success on all 9 Mac projects. The `saves-` column was the only tell. → keep verifying behaviour, not version numbers. |

### 2026-07-30 — v2.12.1: skills never installed on macOS since v2.11.0

**What**: `cp -r "$dir/" dest/` is not portable. With a trailing slash on the source, GNU cp copies the *directory*; BSD cp (macOS) copies its *contents*. v2.11.0 replaced the enumerated skill install with `for skill_dir in .../skills/*/` — that glob appends the slash — plus `cp -r "$skill_dir" .claude/skills/`. On macOS every skill's SKILL.md was therefore written over the previous one at `.claude/skills/SKILL.md`, and **not one skill was ever installed or updated**. The pre-2.11.0 form had no trailing slash and worked on both platforms, so this was a regression introduced while fixing a *different* install bug (the name-enumeration coupling), and never exercised because releases were only tested on Windows.

**How found**: verifying the 2.12.0 rollout on the Mac. Every project reported `saves-` — the retro skill lacked the new Saves section — while `jq+ refl+ stat+ block+` all passed. Evidence: a stray `.claude/skills/SKILL.md` containing **`think`** (last in the loop, so it won), skill dirs still carrying their **March** timestamps while the stray file was dated **Jul 30 18:31** (that day's upgrade), and `/finish` missing from all 9 projects. The Mac had been sitting on 2.10.x, so that upgrade was the first time the broken loop ever ran there.

**Why it stayed hidden**: rules, hooks and agents copy *individual files* (`cp file dst/`), which has no GNU/BSD divergence — so they kept updating correctly and the version marker advanced. From every angle except the skills themselves the install looked healthy. `status`/`doctor` glob `skills/*/`, and a bare file is not a directory, so neither could report it.

**Fix**: copy into an explicit destination instead of relying on cp's directory-vs-contents semantics — `mkdir -p ".claude/skills/$name"; cp -R "$skill_dir"* ".claude/skills/$name/"` — plus removal of the stray file (a bare `SKILL.md` under `skills/` is never a valid skill).

**Verification**: both platforms, before publishing — that is the actual lesson. Windows (GNU cp) and macOS (BSD cp, via the packed tarball over SSH), each with a fresh install and an upgrade-over-existing case. The macOS upgrade case now updates stale skills, restores the missing `/finish`, removes the stray file, and leaves user-authored skill dirs untouched. After publishing, all 22 installs on 3 machines re-upgraded to 2.12.1 and re-verified: version marker, `/finish` present, no stray file, and a live destructive-git command returning exit 2 on every one.

**Gotchas**: the two heavily customized `/self-check` files on 7940 (`gem-platform` 73KB/62 checks, `HUB_Rev1_FW` 8.4KB/6 checks) were clobbered by each upgrade and restored from a local scp backup both times, byte-verified. Until the installer preserves that section, **back it up before every upgrade**. Also: `npx cc-discipline` fails inside this repo, and passing Windows paths through bash double quotes to `ssh`+cmd silently eats backslashes — a batch loop written that way reported FAIL for all 6 projects while actually doing nothing; single-quote the remote command.

### 2026-07-30 — v2.12.2: skills are no longer force-overwritten on upgrade

**What**: Every upgrade replaced all template skills unconditionally. Users tune them per repo — `/self-check`'s "Project-specific Checks" section exists *precisely* to be filled in — so each upgrade silently destroyed that work. On 7940, `gem-platform`'s 73KB / 62-check self-check was wiped twice in one day before this landed; only a manual scp backup saved it. The old install did leave a `.claude/.backup-<ts>/` copy, but nothing told the user anything had been lost.

**How**: the dpkg-conffile approach. `.claude/.cc-discipline-skills.manifest` records the hash of the template we installed for each skill file. On the next upgrade:
- disk hash == recorded hash → untouched, update normally
- disk hash == new template hash → already current, no-op
- anything else → the user owns it: keep their file, write the new template beside it as `SKILL.md.new`, and say so

The manifest is always set to the template shipped that run, **including in the preserved case** — that is what makes adoption self-healing. If the user later moves the `.new` file into place, the next run sees `disk == manifest` and silently resumes updates; if they keep their own version, it keeps reminding them. Hash helper falls back through `sha256sum` → `shasum -a 256` → `md5sum` → `md5` → `cksum`, so it works on macOS and Git Bash alike (macOS resolves to `shasum`).

For installs predating the manifest, a file differing from the template cannot be classified as "older version" vs "user edited", so it is treated as user-edited — the non-destructive assumption. Freshly upgraded installs match the template exactly, so the manifest seeds with zero noise.

**Verification**: five scenarios on **both** platforms before publishing — fresh install; clean re-upgrade (0 `.new` files); user edits to `/self-check` and `/think` preserved while an untouched `/retro` still received a framework update; adoption self-healing (`~` becomes `✓` after taking the `.new`); and the no-manifest legacy transition. Then in production across all 22 installs: cc-discipline's own customized self-check was preserved **automatically** (no manual restore for the first time), and on 7940 both `gem-platform` (73305 bytes / 62 checks) and `HUB_Rev1_FW` (8454 bytes / 6 checks) survived a real upgrade byte-identical to the original backup, each with a `~ /self-check` warning and a `.new` offered.

**Final state**: 22 installs on 3 machines at v2.12.2 — MS-01 (7), mac-mini-m4 (9), techhu-7940 (6). Every one re-verified with a live destructive-git command returning exit 2, plus manifest present and `/finish` installed.

**Gotchas**: I repeated the documented bash-double-quote-to-ssh mistake and the six 7940 upgrades silently did nothing — the version marker (still 2.12.1) was again the only tell, exactly as recorded earlier the same session. Single-quote remote commands. Also, `%CD%` is a useless probe for testing whether a remote `cd` worked: cmd expands `%VAR%` at parse time, before the command runs, so it always reports the pre-`cd` directory.

### 2026-07-30 — v2.12.3: git-guard stops tripping on commit messages

**What**: git-guard matches command *text*, so a message that merely **described** a destructive command was indistinguishable from running one. It blocked three commits this session — including two release commits whose messages documented the very commands the guard exists to catch.

**How**: blank out the CONTENT of message-style arguments (`-m`, `--message`, `-F`, `--file`) before matching. That argument is data and can never execute, so removing it costs no protection.

**Why NOT the more obvious fix**: a general "ignore anything in quotes" rule was considered and rejected — it opens a real hole, because these *do* execute what they quote and must keep matching: `bash -c "…"`, `eval "…"`, `ssh host "…"`. The narrow rule has no such blind spot. Escaped quotes inside a message end the match early and leave the tail to be scanned; that direction is a false positive costing one turn, never a miss — the correct asymmetry for the only guard whose failure means unrecoverable loss of uncommitted work.

**Known limitation** (deliberate): the exemption covers message arguments only. Writing *documentation* about these commands through a shell heredoc still trips the guard, because that text is not in a `-m` argument and the guard cannot know a heredoc is inert. Use the Write tool for such files, or `git commit -F <file>`. Widening this further would start eroding real protection.

**New**: `tests/git-guard-matrix.sh` — 25 cases across must-block (bare commands, compound `&&`/`;`, `bash -c`, `eval`, `sudo` prefix), must-pass (messages describing destructive commands via `-m`/`--message`/`-F`, plus `grep -F`), and safe-commands-still-pass. Registered in CLAUDE.md Project Tools and in self-check's Project-specific Checks so it cannot quietly be skipped. Not shipped to npm (`tests/` is absent from package.json `files`).

**Verification**: 25/25 on GNU sed (Windows) **and** BSD sed (macOS) before publishing — the guard's `sed -E` is exactly the kind of code that diverges between the two, which is what the v2.12.1 bug taught. Then rolled out to all 22 installs on 3 machines and re-verified; 7940's two customized self-check files survived a third consecutive upgrade byte-identical. Final proof was this repo's own commit: its message describes the destructive commands inline via `-m` and went through without the `-F` workaround.

**Session totals**: v2.12.0 → v2.12.3, 7 platform/design bugs fixed, all traced to the same root pattern — *code that behaves differently on another platform or in another quoting layer, failing silently in the safe-looking direction*. jq absent (5 reads), BSD vs GNU `stat` argument order, BSD vs GNU `cp` trailing-slash semantics, CRLF in a shebang, bash `printf` eating a backslash level, and text matching that could not separate data from execution.
| 2026-07-30 | SAVE | /self-check §6 scaffolding | The scaffolding check caught three things I had skipped: status/doctor were never run after substantial init.sh changes; the jq-fallback audit was never re-run after the last git-guard edit; and the git-guard matrix had not been run on 7940 at all — while I had already written a "three platforms verified" header. All three came back clean, but the header was a claim ahead of its evidence. It also exposed a flaw in the check's own text (it recommended `bash init.sh` directly, which on Windows reports `Version: unknown` and looks like a regression). → the check earns its place; keep it. |

### 2026-08-28 — v2.13.0: retired /finish and /retro, folded retro's value into /self-check

**What**: Removed the two skills that four weeks of measurement showed were dead, and merged the part of `/retro` worth keeping into `/self-check`. Net: the framework got smaller, and the measurement it depends on got more reliable.

**Why (measured, not assumed)**: 397 sessions across 3 machines since 7/30. `/finish` invoked **3** times, `/retro` **2**, against `/self-check`'s **385**. `/retro`'s non-use is the direct and complete explanation for the Rule Ledger still holding 7 entries, all written the day it was created. A second reason for `/finish`: it was designed for a model that stops early, and Anthropic's own Opus 5 description says it "completes full tasks rather than leaving stubs or placeholders" — so it was pushing in the direction the model already goes, the same class of thing v2.12.0 deleted elsewhere.

**How**:
- `/self-check` §7 changed from "What's working well?" to "Did the rules change anything this time?", carrying `/retro`'s two bars verbatim: a **Save** must have *changed the outcome* ("the rules kept me disciplined" does not count), and **Friction** only counts with a concrete `→ fix:`. It appends to the Rule Ledger automatically, under the same "recording an observation needs no sign-off" rule §5 already uses. **Moving that write from a skill used twice to one used 385 times is the entire point** — the ledger stops depending on anyone remembering.
- The "note one thing that went well" line survives as the fallback when there is no save, keeping the tone intent from Decision #8.
- `init.sh` gained a retirement pass: a skill present in the *old* manifest but no longer in `templates/` is deleted — but only when its files still match the recorded hashes. Modified ones are kept and reported; an install with no manifest is left alone entirely. Same conffile rule as the v2.12.2 overwrite guard, applied to removal instead.
- `/think` lost its `and finish` downstream directive.

**Gotchas**: The install loop only ever copies, so without the retirement pass all 22 installs would have carried both dead skills forever. The old manifest must be snapshotted **before** the install loop overwrites it — otherwise the removal pass sees only currently-shipped skills and finds nothing to retire.

**Verification**: 4 scenarios, all with `jq` absent. (1) Fresh install → 6 skills, manifest 6 lines, neither retired skill present. (2) Simulated 2.12.3 install carrying both skills plus their manifest entries → both removed. (3) Same, but with `/retro` edited first → `/finish` removed, `/retro` kept with a warning, and a user-authored `my-own` skill untouched. (4) No manifest at all → nothing removed. Then `status` reads `Skills: 6`, `doctor` gives exactly the expected 3 warnings, and all 7 hooks still exit 0.

### 2026-08-28 — v2.13.0 (cont.): hash-algorithm defect + new-script branch removed

**What**: Two fixes folded into the unpublished 2.13.0, plus a measurement that reframes a documented constraint.

**The defect, found by external review before it shipped**: `_cc_hash` in `init.sh` falls back through `sha256sum` → `shasum` → `md5sum` → `md5` → `cksum`, but the skills manifest recorded only the digest, never which algorithm produced it. If tool availability differs between the run that wrote the manifest and the run that reads it, every recorded hash mismatches, every retired skill is classified as user-modified, and **the retirement pass — the entire reason 2.13.0 exists — silently does nothing.** Same failure class as the jq-only reads: environment drift, silent, in the safe-looking direction. Fixed by recording `<algo>:<digest>`; legacy bare digests written by 2.12.2/2.12.3 are matched by trying each available algorithm rather than being declared modified.

Two further edge cases in the same block: a blanket `rm -rf` on a retired skill directory also destroyed user files placed there that the manifest never recorded (now deletes only recorded files, then `rmdir` only if that leaves the directory empty, reporting the partial case separately); and a skill kept as "modified" was excluded from the new manifest, so it could never be reconsidered and was frozen in place permanently (its old entries are now carried forward).

**New-script branch removed**: 2,170 firings in four weeks across two machines at ~50 tokens each, almost all on one-off transform scripts. The apparent correlation with a growing Project Tools section did not survive checking — `/commit` carries the same instruction, and the proposed "gate on whether the heading exists" alternative was disproven because `templates/CLAUDE.md` ships that heading, so every generated project has it. The two projects observed without it simply arrived with their own `CLAUDE.md`, which `init.sh` never overwrites; the distinction was template-generated vs hand-written, not maintained vs neglected.

**Measurement that reframes a constraint**: `CLAUDE.md:12` claims hooks are `<100ms`. On this Windows/Git Bash checkout the three hooks that fire on every edit take **1,267 ms combined** (pre-edit-guard 749, streak-breaker 347, action-counter 171), against a 66 ms floor for a hook that only runs one `cat`. Root cause is process startup: 65 `grep`/`sed`/`awk`/`basename` calls across the three files at roughly 20-30 ms each on Git Bash. Removing the new-script branch took pre-edit-guard from 838 to 722 ms on a `Write` payload. **This is deliberately left unfixed** — it refactors the parsing core of the framework's only enforcement layer, and this repo's recorded failure mode is exactly that such changes look fine and break silently on another platform. It needs its own pass with before/after numbers on both platforms.

**Also disproven**: `$FILE_PATH` is not normalized against `$CWD` before the existence check, which the previous plan called a defect. 1,776 real `Write` calls extracted from 123 local transcripts since 2026-07-30 were **1,776 of 1,776 absolute drive-letter paths, zero relative**. It is a latent robustness gap with no production impact. The claim that the repo smoke test exercised that path was also wrong: the test sends `tool_name: "Edit"` and the branch requires `Write`.

**Verification**: 7 scenarios, `jq` absent throughout. Fresh install → 7 skills, all manifest entries carry the `sha256:` prefix. Legacy bare-digest manifest → retirement works. **Manifest written with MD5 digests** (simulating a machine without `sha256sum`) → still recognised as pristine and retired, which is the case that silently failed before the fix. Modified retired skill → kept, content intact, entries carried forward into the new manifest. User file inside a retired directory → our file removed, their file kept, directory kept, reported separately. No manifest → nothing removed. All 7 hooks exit 0; git-guard matrix 25/25.

### 2026-08-28 — v2.13.1: manifest comparison now normalizes line endings

**What**: The manifest compared skill files byte-exactly, but git rewrites those bytes. Projects that commit `.claude/` and run with `core.autocrlf=true` and no `.gitattributes` get `SKILL.md` converted to CRLF on checkout, so every skill reads as user-modified: the retirement pass removes nothing and every upgrade drops a `.new` file beside every skill.

**How it surfaced**: during the 2.13.0 rollout, `ziiqii-geosense` reported `/finish` and `/retro` as modified while 16 other installs retired them cleanly. The numbers gave it away — the installed file was 2,862 bytes against a 2,818-byte template, a difference of exactly 44 bytes across exactly 44 lines, and `diff` reported `1,44c1,44`, every line changed. Normalizing to LF reproduced the manifest digest `1013f03c…` exactly.

**Fleet exposure at the time**: `tb-toolkit` and `techhu-devices` were CRLF; four of seven local installs carried leftover `.new` files from the spurious preservation. `techhu-devices` had an `eol=lf` rule in `.gitattributes` that did not cover `.claude/` paths. This repository has a rule that does, which is why all seven pre-release test scenarios passed — the bug was invisible from inside the project that defines the framework.

**How**: hashing now runs the file through `sed 's/\r$//'` first, so line-ending differences are absorbed while real content changes still register. `_cc_hash_matches` accepts an entry under any reading it might have been written with: `<algo>:<digest>` normalized (2.13.1+), `<algo>:<digest>` byte-exact (2.13.0), or a bare digest with both algorithm and normalization unknown (2.12.2/2.12.3). Being permissive is the safe direction here — a false "modified" freezes a skill permanently and buries the user in `.new` files, while a false "pristine" can only overwrite a file that is already byte-identical to what would be installed.

**Verification**: CRLF file against a manifest holding the LF digest → retired correctly (the exact failure case). CRLF file against a legacy bare MD5 digest of the LF content, mismatched on both axes → retired correctly. A genuinely edited file → still kept, content intact. Then the real failing artifact: `ziiqii-geosense`'s CRLF `finish/SKILL.md` fed to the new comparator against its actual manifest entry → judged pristine. Plus git-guard matrix 25/25, all 7 hooks exit 0, fresh install writes 7 algorithm-prefixed entries.

### 2026-08-28 — v2.13.2: the manifest file itself was unprotected

**What**: v2.13.1 taught the comparator to ignore line endings *inside* skill files, then git's own warning during that commit revealed the same problem one level up — `.claude/.cc-discipline-skills.manifest` and `.cc-discipline-version` have no file extension, so `.gitattributes` rules keyed on `*.sh`/`*.md`/`*.json`/`*.js` never matched them. A CRLF manifest puts a stray carriage return on the end of every recorded digest, `read -r rel rec_hash` carries it into the comparison, and every skill reads as modified again — the identical failure, caused by the file that stores the fix.

Reproduced before fixing: a manifest line written with CRLF made a byte-identical `SKILL.md` report as user-modified and blocked its retirement.

**How**: strip a trailing CR from the recorded value at the top of `_cc_hash_matches`, and from `rel` in the retirement loop. Added the two extensionless state files to `.gitattributes` as well, which helps this repository but not user projects — the strip is what protects everyone.

**Gotchas**: the fix took three attempts because of the escaping layers. Writing `${_rec%$'\r'}` through a Python heredoc first produced `${_rec%$'"'"'^M'"'"'}` with a real carriage return embedded, because shell-style quote escaping was applied inside a Python string where it was not needed and `\r` was interpreted rather than kept literal. A `perl -i -pe` repair attempt then failed on its own quoting. Python raw strings with line-number targeting worked. Also: `grep -c $'\r' file` counts every line, not lines containing CR — it reported 816 of 816 and briefly looked like the whole file had been corrupted. `cat -A | grep -c '\^M\$'` is the check that actually works.

**Verification**: CRLF manifest → retires correctly. CRLF manifest plus CRLF skill file → retires correctly. Genuinely edited file → still kept, content intact. User file inside a retired directory → survives while ours is removed. git-guard matrix 25/25.

### 2026-08-28 — v2.13.2 rollout: the project list was wrong, not just stale

**What**: rolled 2.13.2 to all three machines. The rollout itself found that every upgrade since July had been driven by a **hardcoded list of seven projects**, and the list was incomplete: scanning instead for the framework's own marker file (`.claude/hooks/streak-breaker.sh`) turned up 22 installs, three of which — `phenology-twin`, `soil-twin`, `vini-twin` — predate v2.0.0, carry no `.cc-discipline-version` file at all, and had therefore never appeared in any version-based inventory. They had been running pre-2.0 hooks for months.

**Why it matters beyond this rollout**: the inventory question and the upgrade question are different. Asking "which installs are out of date" by reading version files can only ever find installs that already have version files — the oldest ones, which need the upgrade most, are structurally invisible to it. Enumerate by a marker that has existed since the beginning, then treat a missing version file as "very old", not as "not an install".

**Result**: 22/22 on v2.13.2. MS-01 10, mac-mini-m4 5, techhu-7940 7.

**Known limitation, not fixed**: installs that jumped from `<2.12.2` straight to 2.13.x have no manifest, and the retirement pass conservatively removes nothing without one. `/finish` and `/retro` survive there permanently (confirmed on `HUB_Rev1_FW`). Fixing it means shipping the historical digests of the two retired skills so their pristine copies can still be recognized — a one-time special case, deliberately deferred.

### 2026-08-28 — /coplan: putting the plan on disk so Codex can check it against the code

**What**: new skill, `templates/.claude/skills/coplan/SKILL.md`. It writes the plan currently under discussion to `docs/current-plan.md` and stops. It does not produce the plan, does not run the review, does not implement.

**Why a file and not a prompt**: the Codex plugin runs `codex-companion.mjs` at the workspace root, so it reads the repo. A plan pasted into a prompt can only be judged on its own internal logic; a plan sitting in the tree can be judged **against the actual code**. That difference is the whole reason the skill exists, and it is why the file has an **Assumptions to verify** section — the place a plan usually fails is a false premise about the codebase, which is exactly what a reviewer holding the repo can refute and a reviewer holding only the text cannot.

**Design decisions**: fixed path, no optional argument — one plan at a time. (The original justification for overwriting, *"every earlier version survives in `git log -p`, so nothing is lost"*, was circular and has been removed — see the 2026-09-01 entry. The file is now untracked.) Independent of `/think` but designed to stack with it: `/think /coplan <task>` produces the approaches and puts them on disk with the choice **still open**, because the review is meant to inform the decision rather than ratify one. That required a carve-out in `/think` Step 5, which otherwise forbids creating files — writing the plan down is not implementation.

**Two Codex engines, distinguished** (recorded in the techhu-devices memory file, not here): `/codex:review` looks for defects in a diff; `/codex:rescue` is adversarial and questions the approach itself. A plan wants `rescue`. `rescue` does default to a write-capable run, but `agents/codex-rescue.md:34` conditions that default: it adds `--write` *"unless the user explicitly asks for read-only behavior **or only wants review, diagnosis, or research without edits**"*. Saying `只评审方案` hits that documented branch rather than getting lucky. `review` cannot write at all — `codex-companion.mjs:414` hardcodes `sandbox: "read-only"`.

### 2026-08-30 — AGENTS.md: decided against for Claude-Code-led repos

An earlier note in this file argued that `AGENTS.md` was the right place for hard boundaries, on the grounds that Codex reads it and never reads `CLAUDE.md`. **That argument is wrong and has been removed above.** It fails on ordering:

```
Claude decides whether to pass --write
   ↓
sandbox: request.write ? "workspace-write" : "read-only"   <- codex-companion.mjs:491
   ↓
Codex process starts
   ↓
Codex reads AGENTS.md                                      <- gate already closed
```

`AGENTS.md` is read **downstream of the only real gate**, so it cannot influence the sandbox its own process runs under. The write decision belongs to `agents/codex-rescue.md`, on the Claude side, and that file already handles it. Worse, even if Codex did obey an `AGENTS.md` line saying "do not modify files", that is one more *advisory* layer — precisely the layer this project's entire thesis distrusts for anything that can lose work.

The sandbox is also **binary and has no path granularity** (`:491`), so "let Codex edit only `docs/current-plan.md`" is not an expressible permission. It decomposes into "open write on the whole workspace, then ask nicely". (Do not confuse this with the `--scope` flag at `:80` — that selects the *diff range* for `review`/`adversarial-review`, not a write scope.)

**Criterion for whether a repo needs one: does Codex actually modify files here?** Review-only, as in every current repo → no. `AGENTS.md` is a productivity document (build and test commands, conventions, directories to leave alone), not a safety one; it earns its place the day Codex is given `--write` to implement something, and not before. Writing it now would mean guessing at contents that are only knowable then.

**Related, on plan review**: letting Codex rewrite `docs/current-plan.md` and reading the diff was considered and rejected. It saves the cheapest step (applying prose feedback with a few edits) and spends the most expensive one — a diff reads as a verdict and quietly erodes the "opinions are input, not judgment; verify each one first" discipline. It also discards the evidence, which is the actual deliverable of a plan review, and `git diff` would not show any untracked file Codex created. The cheap fix for review latency is prompt shape, not write access: ask Codex to answer **keyed to the numbered `Assumptions to verify` entries**, each as `number · holds / does not hold / cannot tell · evidence (file:line)`. That section was designed as a review anchor; the prompt just never used it.

### 2026-09-01 — v2.13.3: /coplan's plan file is a scratch file, and must not be tracked

**What happened**: in a firmware repo, a commit whose message read `docs(plan)` also carried two `printf("[STACKPROBE] ...")` lines in `components/cli/tb_lite_config_cli.cpp` — instrumentation the source itself annotated `[TEMP INSTRUMENTATION — remove before release]`. It reached `main` and two remotes. The affected command, `test-connect`, is one buyers run during first-time configuration, so a release built from `main` would have printed stack-probe output to customers.

**The connection to `/coplan`**: `docs/current-plan.md` was tracked, and the skill rewrites it on every invocation, so it was permanently in `git status`. A file that is always modified is a **standing passenger** — it rides into unrelated commits whenever anything sweeps the working tree, and it normalizes seeing an unexplained entry in the staged list.

**Trigger vs root cause, kept separate**: the passenger is an *enabler*. The root cause is committing without reading the staged diff — the commit message said documentation while the file list said otherwise, a contradiction one `git diff --cached --stat` would have shown. **No new instruction was added for that**, because `templates/.claude/skills/commit/SKILL.md` already carries both `git diff --staged && git diff` (:31) and *"Selectively `git add` (don't use `git add -A`)"* (:35), and the incident happened anyway. Adding a third phrasing of advice that was already present and already ignored would only confirm this project's own thesis about advisory layers. The mechanical fix is the one that works: remove the passenger rather than ask someone to notice it.

**The justification that was wrong**: the skill said to overwrite because *"every earlier version survives in `git log -p docs/current-plan.md`, so nothing is lost"*. That is circular — preserved history is only a reason when the history is worth keeping. The three drafts produced that evening had a wrong causal model and an arithmetic error respectively; their diffs carry nothing. What was worth keeping — what was wrong and how it surfaced — was already in that repo's progress and gotcha logs. Writing the same fact in three places guarantees two go stale, which that repo had just been bitten by (a `CLAUDE.md` section and `SRAM_BUDGET.md` describing the same thing, one four months out of date and unnoticed).

**How**: `/coplan` now opens with "The file is a scratch file, not a record" — it must be in `.gitignore` before the plan is written, it is never committed by the skill, and an already-tracked copy is reported with `git rm --cached` offered rather than run silently. This repository's own copy was untracked and ignored in this commit.

**Verified it costs nothing downstream**: `/codex:rescue` reads the working tree directly, so an ignored plan file is as readable as a committed one. It also *helps* — `getWorkingTreeState` (`lib/git.mjs:125`) builds its untracked list with `--exclude-standard`, so an ignored file no longer counts toward `isDirty`, removing one permanent trigger of the silent scope narrowing recorded on 2026-08-31.

**Noted**: several other projects had already untracked the file on their own before this change.

### 2026-09-01 — hook latency measured properly; the recorded figures were wrong in three ways

**Method**: instrumented the three installed `PreToolUse` hooks with `$EPOCHREALTIME` (a bash 5 builtin — zero fork, so the probe does not distort what it measures), triggered five real `Edit` calls through the harness, then restored the hooks and verified all three SHA-256 digests matched the pre-instrumentation snapshot. Profiling used `PS4='+ $EPOCHREALTIME | '` with `set -x` on a scratchpad copy.

**Finding 1 — the three hooks run in parallel.** Consecutive PIDs, all three starting within 15 ms of each other, intervals fully overlapping. The earlier assumption of serial execution was never checked.

**Finding 2 — contention between them is negligible.** `pre-edit-guard` costs the same run alone (755 ms) as it does with the other two running beside it (728-834 ms). An earlier claim in this session that parallelism made each hook twice as slow was wrong; the apparent slowdown was a payload difference, not contention.

**Finding 3 — cost depends on the target file, by roughly 3x.** `pre-edit-guard` exits early for `docs/` paths (:25), for basenames matching `test|spec` (:30), and for `.md/.json/.yaml/.yml/.toml/.cfg/.ini` (:35). Everything else runs the full path, including an `awk` pass over `docs/debug-log.md` and three `count_lines` calls over `new_string`/`content`/`old_string`.

| target | measured |
|---|---|
| `docs/progress.md` | 283 ms |
| `README.md` | 356 ms |
| `probe.sh` | 755 ms |
| `init.sh` | 800 ms |

**What this corrects**: the previously recorded "1267 ms per Edit, 65 subprocess calls" was wrong three times over — it summed hooks that run in parallel, it counted subprocess occurrences in source rather than executions, and it was measured against a markdown payload that takes the cheap path. The real figure is **~770 ms when editing source, ~300 ms when editing docs**, and the critical path is `pre-edit-guard` alone: the other two finish at 355 ms and 180 ms, entirely inside its shadow.

**What this means for any fix**:
- **Optimize `pre-edit-guard` only.** Work on the other two buys nothing while they finish inside its runtime.
- **There is no hotspot.** The profile shows 69 traced steps over 728 ms; the twelve most expensive account for only 39%. Cost is spread thin at roughly 10-30 ms per step because each step is a fork. Even `command -v jq` costs 19.8 ms.
- **Merging the hooks into one process is probably a pessimization**, not an optimization: it would serialize work that currently overlaps. This is the opposite of what the draft plan assumed.
- **`CLAUDE.md:12`'s `<100 ms` is unreachable on any path.** Even the cheapest early-exit route costs 283 ms, and that is three `echo | grep` pipelines plus a `command -v` before the hook decides it has nothing to do.

**Still unmeasured**: macOS and Linux, where `fork` is far cheaper; and whether jq being present changes the picture, since this box has none.

### 2026-09-02 — /coplan reworked from a usage survey, and one proposal withdrawn

**What was asked**: four days after `/coplan` shipped, a short survey went to three repos — do you use it, where is the friction, is "Assumptions to verify" earning its place, do you actually send the review, does `/think` stacking work. Three responses came back; a fourth was a duplicate paste of the first and was discarded rather than counted as independent agreement.

**Usage, and why the obvious reading was wrong**: all three reported **zero self-initiated** invocations, and one explicitly proposed applying the `/finish` and `/retro` retirement standard. That reading measures the wrong actor. `/finish` and `/retro` were designed to be model-initiated and were not; `/coplan` is user-initiated by design, and the user invoked it three times in four days across three repos, each time for its stated purpose — producing a plan file to send for external review. Compared against `/commit` and `/think`, that is normal adoption. What the data does condemn is the skill's own `when_to_use`, which was phrased as if the model would reach for it. Fixed.

**Converged findings (3/3)**:
- The skill is invoked once per plan; every later revision is hand-editing. "Overwrite completely" described a mode that does not occur.
- All friction sits *after* the review returns — one respondent spent over an hour folding 22 findings into a file that had grown to 785 lines. The skill has no presence in that phase.
- The review request's wording determines the review's quality, and the skill supplied one generic line. Independently confirmed by this repo's own Codex run the same day, which returned a diffuse review against an unfocused request.

**Where the responses disagreed, and the dissent won on detail**: two respondents called *Assumptions to verify* the skill's real product (one reported 3 of 8 and 3 of 7 entries coming back FALSE, each changing the design). The third disagreed with a sharper argument: the findings that mattered in their case were scattered through the whole document, and **the most expensive error was not an unchecked assumption but a checked one with a stale source** — the plan cited `RELEASE_NOTES.md:31`, the reviewer opened the same line, and both were wrong together. The section asks "what did I not check"; it cannot reach "I checked, in the wrong place." Section 4 now asks both questions.

**A rule worth having, from the second respondent**: an entry belongs in that section only if it can be falsified by opening a named file or running one command. Anything else ("assumes the quarterly cron will run") can only earn "holds with caveats" and belongs in Risks. Paired with the converse, learned here the same day: anything checkable in under a minute should be checked while writing, not parked for a reviewer. That section had become a respectable way to write "I did not bother."

**Proposal withdrawn**: two respondents wanted the version history back — one asked for a diff on repeat invocation, another had built a `docs/plans-archive/` directory by hand. Both were reacting to a real loss caused by 2.13.3's untracking. **Adding an archive was drafted and then dropped**: 2.13.3's own commit message says a third location holding the same facts guarantees two go stale, and the user confirmed the record is `progress.md` plus git history. The near-miss is worth recording — a fix proposed one day was almost reversed the next by treating one agent's local improvisation as an established convention. The diff feature would also never have fired, since nobody re-invokes the skill. The cost is now written into the skill as an accepted trade, not silently carried.

**Also changed**: the no-fabrication guard is called out as the file's most important line, after a respondent observed that inventing content on invocation is the hardest failure to self-detect. A closing note warns that a plan file gives an estimate a citable form, which the next revision then treats as established — the mechanism behind six review rounds all finding the same class of error, "推算被写成实测".
