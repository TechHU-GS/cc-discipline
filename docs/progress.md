# Progress & Decision Log

> Maintained by Claude Code during work sessions. Read this file after compact to restore context.

---

## Current Status

- **Last shipped (this session)**: v2.12.3 — git-guard no longer trips on commit messages describing git. Preceded by v2.12.2 (skills no longer force-overwritten, manifest-based). Preceded by v2.12.1, the macOS skills-install fix. Preceded by v2.12.0, the Opus 5 adaptation audit + 5 platform bug fixes. **Committed (992b0ce), pushed, and published to npm as 2.12.0 on 2026-07-30.** Verified by pulling the published tarball back from the registry: shasum `b7e93487…` matches the local pack, `cli.js` shebang clean, git-guard fallback / retro Saves / Rule Ledger all present. Second bucket (evidence-backed rules) deliberately frozen pending 2-3 weeks of real Opus 5 usage data.
- **Previous release**: v2.11.0 — (1) new /finish skill + /think `and finish` wiring; (2) self-check progress.md auto-update + `disallowed-tools: AskUserQuestion`; (3) soundness-review red items: install scripts directory-driven, pre-edit-guard per-edit bug-fix nag removed, action-counter session_id bug fixed. **Committed (ac52b72), pushed, published to npm 2026-06-05**.
- **Last updated**: 2026-07-30
- **All 22 installs across 3 machines are on v2.12.3 (2026-07-30)**. MS-01 (this box, 7), mac-mini-m4 `techhu@100.64.0.8` (9), techhu-7940 `techhu_dev@100.64.0.18` (6 active; the 2 `_private-reference` archives and the `.claude/worktrees/` copy were deliberately skipped). Both remotes reachable over Tailscale with passwordless SSH from here. Global `~/.claude/CLAUDE.md`: MS-01 and mac-mini corrected; 7940 was already current. The rollout is what surfaced the macOS skills bug — see v2.12.1 below.
- **Superseded — the 2.12.0 pass**: cc-discipline (2.9.1), litevna-test (2.8.0), tb-toolkit (2.9.1), techhu-devices (2.10.0), wechat-visual (2.10.2), ziiqii-geosense (2.10.2), ziiqii-techhu (2.10.1). All 7 verified: version marker, jq fallback present, reflection block gone, stat order fixed, retro Saves present, live `git clean -fd` interception returns exit 2, post-error-remind silent on the former false-positive payload, memory + CLAUDE.md intact. All 10 user-authored skills survived (`gem-vc`, `dev-machines`, `hub`, `ingest`, `kb-search`, `kb-sync`, `onboard-casdoor-user`, `reindex`, `sync`, `wechat-publish`); 5 projects additionally gained `/finish`, which they had been missing since they were below 2.11.0. `E:\Code\tb-dashboard` has a transcript dir but no longer exists on disk.
- **Next steps**: (0) **`upgrade` overwrites customized skills** — it wiped this repo's `/self-check` Project-specific Checks (restored by hand from a pre-upgrade copy). That section is explicitly designed for user content, so the installer should merge or preserve it rather than overwriting it. **FIXED in v2.12.2** — manifest-based detection, verified in production on the two 7940 files. (1) **DONE — git-guard commit-message false positive fixed in v2.12.3** (message-argument blanking + tests/git-guard-matrix.sh). (2) After 2-3 weeks of Opus 5 use, read the Rule Ledger and decide the frozen bucket (00 §6, 01-debugging, 05-phase, 07 §4a, /investigate). (3) Security: the npm token pasted in chat 2026-06-05 should be rotated. — DONE this session: `~/.claude/CLAUDE.md` line 44 corrected (it had asked Claude to warn when context is nearly full, which Opus 5 cannot observe: per Anthropic's docs, context awareness exists on Sonnet 5 / Sonnet 4.6 / Sonnet 4.5 / Haiku 4.5, and Opus 5 is not on that list — so the instruction could only be satisfied by guessing, which produced the exact noise the replacement text forbids).
- **Published**: v2.10.1 (tone rewrite), v2.10.2 (CRLF hotfix + .gitattributes), v2.10.3 (self-check Project-specific Checks), v2.11.0 (/finish + friction fixes + framework hardening), v2.12.0 (Opus 5 audit + 5 platform bugs), v2.12.1 (macOS skills install fix), v2.12.2 (skills no longer force-overwritten), v2.12.3 (git-guard message-arg fix)

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
| 14 | Record rule **saves**, not just friction | A working rule suppresses the failure it was written for, so only its cost is naturally observable; cost-only data eventually cuts load-bearing rules | /retro, progress.md Rule Ledger | 2026-07-30 |

---

## Rule Ledger

<!--
Appended by /retro. Two kinds of evidence about the discipline rules themselves:

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
