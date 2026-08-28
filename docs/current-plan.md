# Current Plan

> Written by `/coplan`. Overwritten each time — earlier versions are in `git log -p docs/current-plan.md`.

## Task

Decide what to do next in this repository. This is the second revision: an external review plus follow-up measurement invalidated three claims in the previous version and surfaced a larger problem that was not on the list at all.

## What measurement established

**Hook latency is 12x over the documented budget.** `CLAUDE.md:12` states "Hooks must be lightweight (<100ms)". Measured on this Windows/Git Bash checkout, 10 samples each, realistic Edit payload:

| Hook | Latency | Subprocess calls in file |
| :--- | ---: | ---: |
| `pre-edit-guard.sh` | 749 ms | 29 |
| `streak-breaker.sh` | 347 ms | 19 |
| `action-counter.sh` | 171 ms | 17 |
| **Total per Edit** | **1267 ms** | **65** |
| `phase-gate.sh` (no parsing, one `cat`) | 66 ms | — |

All three fire on every Edit/Write/MultiEdit per `.claude/settings.json`. The 66 ms floor for a hook that does nothing shows the cost is process startup: on Git Bash each `grep`/`sed`/`awk`/`basename` invocation costs roughly 20-30 ms, and these three files contain 65 of them. Expected to be far cheaper on macOS and Linux, so this is a platform-specific performance problem rather than a logic error.

**`$FILE_PATH` normalization has no production impact.** 1,776 real `Write` tool calls were extracted from 123 local transcripts since 2026-07-30. **1,776 of 1,776 used absolute drive-letter paths; zero were relative.** The missing `$CWD` normalization at `pre-edit-guard.sh:104` is a latent robustness gap, not a live defect. The previous revision claimed the repo smoke test proved this path was exercised; that was wrong, because the smoke test sends `tool_name: "Edit"` and the branch requires `Write`.

**A "Project Tools heading exists" gate would not reduce noise.** `templates/CLAUDE.md:54` ships that heading, and `init.sh` generates `CLAUDE.md` from the template on fresh installs while never overwriting an existing one. Every framework-generated project therefore has it. The two sampled projects lacking the heading are ones that arrived with their own `CLAUDE.md` — the observed distinction was template-generated vs hand-written, not maintained vs neglected. The previous revision read that correlation as evidence of an active registration habit.

**The retirement logic added in the unpublished 2.13.0 has a real defect.** `_cc_hash` (`init.sh:405-410`) falls back through `sha256sum` → `shasum` → `md5sum` → `md5` → `cksum`, but the manifest records only the digest, never which algorithm produced it. If tool availability changes between runs — the same class of environment difference that caused the `jq` failures documented in `CLAUDE.md` — every recorded hash mismatches, every retired skill is classified as user-modified, and nothing is ever removed. Two further edge cases: `rm -rf` on a retired skill directory also deletes user files placed there that the manifest never recorded, and a skill kept as "modified" is excluded from the new manifest and so never reconsidered.

## Approaches

### A. Publish now, defer everything

Commit the `/coplan` work, publish 2.13.0 as it stands, roll out to 22 installs.

- **How**: commit, push, publish, upgrade each install, verify each version marker.
- **Cost**: one release cycle.
- **Gives up**: ships the hash-algorithm defect, so the retirement pass this release exists to deliver may silently do nothing on some machines. Leaves 1267 ms per edit and the 2,170-firing branch in place until a later release.

### B. Fix what this release introduces, then publish once

Repair the hash-algorithm defect, delete the new-script branch, then publish and roll out.

- **How**: record the algorithm alongside each digest in the manifest, or pin one algorithm and treat an unreadable digest as "unknown, do not delete"; narrow the retirement deletion to files the manifest actually recorded; remove the `NEW SCRIPT DETECTED` block from both copies of `pre-edit-guard.sh`; then commit, publish, roll out.
- **Cost**: one hook file and one install script, each in **two** copies (`templates/` is source of truth, `.claude/` is the dogfood install), plus one release cycle.
- **Gives up**: leaves the 1267 ms latency for a later pass.
- **Note**: deleting the new-script branch also removes work from the hottest hook, so it helps latency as a side effect.

### C. Include the latency work

B, plus reducing subprocess count across the three hot hooks.

- **How**: collapse repeated `grep`/`sed` extractions into a single pass per hook; replace `basename` and `wc` calls with shell parameter expansion; parse the JSON payload once rather than repeatedly.
- **Cost**: rewrites the parsing core of the three hooks that constitute the framework's only enforcement layer, plus full re-verification on Windows and macOS with `jq` absent.
- **Gives up**: nothing functionally, but it is the largest change and mixes a performance refactor into a release that already retires two skills, making attribution hard if something regresses.

## Recommendation

**B.** The hash-algorithm defect sits in code written this session and not yet published, so fixing it now costs one edit and prevents shipping a retirement pass that may be inert — and delivering that pass is the entire reason 2.13.0 exists. Deleting the new-script branch is now well supported: an external review recommended it, the heading-gate alternative is disproven, and the measured registration correlation was shown to be confounded by `/commit`.

The latency finding has more daily impact than anything else here, but it refactors the three files that are the framework's enforcement layer, and this repository's recorded failure mode is exactly that such changes look fine and break silently on another platform. It deserves its own pass, its own before-and-after measurements, and its own two-platform verification — not a ride along with a skill retirement.

A is not recommended: it publishes a release whose headline feature may do nothing on some machines.

## Assumptions to verify

1. **That `Write` is the only path into the new-script branch.** Deleting it assumes nothing else depends on that block. `MultiEdit` shares the same matcher but the branch tests `TOOL_NAME = "Write"`.
2. **That no install has a user-authored file inside `.claude/skills/finish/` or `.claude/skills/retro/`.** If one does, the current retirement deletion removes it. Unverified across the fleet.
3. **That recording or pinning the hash algorithm does not break manifests already written by 2.12.2 and 2.12.3.** Those exist on all 22 installs and contain bare digests with no algorithm field.
4. **That the measured latency reproduces on macOS.** All numbers here come from one Windows/Git Bash machine. If macOS is already under 100 ms, the constraint in `CLAUDE.md:12` is platform-conditional and should say so rather than being treated as universally violated.
5. **That removing the new-script branch measurably reduces `pre-edit-guard.sh` latency.** Plausible but unmeasured; the branch sits near the end of the script and several earlier exits bypass it entirely.

## Risks and unknowns

- Rolling out to 22 installs has silently done nothing twice in recorded history, both times because a shell quoting layer swallowed the command. The version marker is the only trustworthy check.
- The causal question behind the new-script branch — whether it, `/commit`, or neither drives Project Tools registrations — remains unresolved. B deletes the branch without resolving it, accepting that `/commit` keeps the same instruction.
- The npm token flagged for rotation since 2026-06-05 outranks every item here in severity and cannot be addressed from inside this repository.

## Out of scope

- The frozen rule bucket (`00` §6, `01-debugging`, `05-phase`, `07` §4a). Rules leave no mechanical trace; nothing here produces evidence about them.
- Migrating hooks, skills and agents to the plugin distribution mechanism.
- `$FILE_PATH` normalization, now measured as having no production impact.
- The split auto-memory directories, which operate on machine state rather than repository code.
