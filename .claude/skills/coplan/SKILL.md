---
name: coplan
description: Write the plan under discussion to docs/current-plan.md so an external reviewer can check it against the real code. User-invoked; stacks after /think.
when_to_use: Only when the user asks — an explicit /coplan, or "落个方案" / "写下来给 codex 看" / "把方案存一下", or /coplan stacked after /think. Whether a plan is worth an external review is the user's judgement, not yours; do not reach for this on your own.
---

Write the plan under discussion to `docs/current-plan.md`, then stop.

This skill does not produce the plan and does not decide anything. It takes whatever is on the table — the approaches from `/think`, or a plan just described in conversation — and puts it where a reviewer can read it. Codex runs read-only from the repo root, so a plan **on disk** is one it can check **against the actual code**. That is the entire point: a plan pasted into a prompt can only be judged on its own terms, while a plan in the tree can be judged against what is really there.

If there is no plan on the table yet — no approaches from `/think`, nothing described in conversation — **say so and stop**. Point at `/think` instead. Do not invent a plan just to have something to write: a fabricated plan sent for review wastes a review run and produces confident feedback on something nobody proposed. Fabricating content when a skill is invoked is the hardest failure mode to catch in yourself, which makes this the most important line in this file.

## The file is a scratch file, not a record

**It must not be tracked by git.** Before writing, make sure `docs/current-plan.md` is in `.gitignore`; add the line if it is missing. If the file is already tracked, say so and offer to untrack it with `git rm --cached docs/current-plan.md` — do not run that silently, and never commit this file yourself.

- **A tracked file that is always modified becomes a standing passenger.** It sits in every `git status`, so it rides into unrelated commits whenever anything sweeps the working tree. This has already happened: a commit whose message said it touched only documentation also carried temporary debug instrumentation onto `main`. Untracking removes the passenger; telling someone to be careful does not — `/commit` already says to stage selectively, and it happened anyway.
- **It is not where the decision lives.** What was decided and why belongs in `docs/progress.md` and in commit messages. Do not create an archive directory for old plans: a third place holding the same facts only guarantees two of them go stale.

**Known cost, accepted deliberately**: because the file is untracked, hand-edits between revisions no longer show up in `git diff`, so you lose the view of what you just changed. Self-contradictions have survived several revisions unnoticed for exactly this reason. That cost is smaller than instrumentation reaching `main`. If a revision matters enough to remember, write the one sentence into `progress.md` — if you cannot write that sentence, it did not matter.

## What to write

**Overwrite the file completely.** One plan at a time; a superseded draft has no further use.

Include, in this order:

1. **Task** — what is being asked, in a sentence or two, framed the way the user framed it rather than the way you re-scoped it.
2. **Approaches** — two or three. For each: how it works, what it costs, what it gives up. If there is genuinely only one reasonable approach, say so and say why. Do not invent alternatives to fill the section.
3. **Recommendation** — which one, and the reason. A recommendation, not a survey.
4. **Assumptions to verify** — see below. This is the section reviewers falsify most.
5. **Risks and unknowns** — what could go wrong, and what you could not determine. Anything a reviewer cannot settle by reading the repo belongs here, not in section 4.
6. **Out of scope** — what this deliberately does not touch, so a reviewer does not flag choices as omissions.

Write it for someone who has the codebase but was not in this conversation. No "as discussed above", no pronouns pointing at chat history.

### Section 4 in detail

Two questions, not one. The second exists because the first does not reach the more expensive failure.

**"What am I relying on that I have not checked?"** Every claim the plan rests on: "assumes this is only called from X", "assumes the migration runs before Y", "assumes no other caller depends on the old shape".

Two rules for what belongs here:

- **It must be falsifiable by opening a named file or running one command.** "Assumes the quarterly cron will actually run" is not an assumption, it is an unknown — a reviewer can only answer "holds with caveats". Put it in section 5.
- **If you can check it yourself in under a minute, check it now** and write the conclusion instead. This section is for what you cannot cheaply verify. It is not a parking place for what you did not bother to look up, and treating it as one wastes a review run on something a `grep` would have settled.

**"What did I check, and how current was the source?"** For every load-bearing fact you *did* verify, name the source with a line number and say how fresh it is. A stale source is more dangerous than an unchecked assumption, because the reviewer opens the same file and inherits the same error — that has happened here: a plan cited `RELEASE_NOTES.md:31`, the review cited the same line, and both were wrong together. Flag anything sourced from a comment, a changelog, or a doc rather than from code that runs.

## Then stop

Report the path, then hand over a review request the user can send as-is. **A generic request produces a generic review** — what makes a review land is naming what to check and demanding a shape for the answer. Fill the bracketed parts from the plan you just wrote:

```
Plan written to docs/current-plan.md

To have Codex review it:
/codex:rescue 只评审方案，不要修改任何文件。方案见 docs/current-plan.md。

请对着 [列出具体文件/目录] 核实，逐条正面回答 "Assumptions to verify" 的编号，
每条只给三样：编号 · 成立/不成立/查不到 · 证据（文件:行）。
其余问题另列，不要展开成散文。
```

**Do not run the review yourself** — that call belongs to the user. **Do not start implementing either**: writing a plan down is not approval to build it.

## When stacked after /think

`/think /coplan <task>` is the intended pairing. `/think` produces the approaches and stops for the user's choice; `/coplan` puts them on disk on the way past.

Write the file with the approaches **still open**. The review is meant to inform the choice, not rubber-stamp one already made — so do not collapse the section down to your recommendation just because you have one.

## What this skill does not do

The friction in this workflow is concentrated *after* the review comes back — verifying each finding locally and folding it in — and this skill is not in that path. Be aware of a related hazard while writing: putting an estimate in a plan file gives it a formal, citable form, and the next revision tends to treat it as established. Mark estimates as estimates in the text itself.
