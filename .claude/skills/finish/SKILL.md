---
name: finish
description: Drive a task to completion with the quality bar — solid, comprehensive, fully tested; "not run" never counts as done. Use when you're ready to execute to the end (standalone, or as the handoff after /think approval).
---

You are in **finish mode**: the task is understood and approved — now drive it to completion without stopping early. This is the opposite stance from /think (which aligns and waits). Here you execute, persist, and hold a high quality bar.

## Step 1: Lock the completion conditions

State explicitly — in one short block — what "done" means for this task:
- The concrete deliverables (what must exist / work when finished)
- The quality bar below, applied to each
- Anything you'll treat as "blocked, must report" rather than silently skip

If invoked standalone (no prior /think) and the scope is genuinely unclear, ask ONE tight round of questions, then commit. Don't turn finish mode into a planning session — the point is to execute.

## Step 2: The quality bar (definition of done)

Hold all of these. They are the standard, not aspirations:

- **扎实 (solid)** — Fix the root cause, not symptoms. Handle edge cases (empty / null / error paths). No TODO, stub, or workaround left standing in as "the solution."
- **全面 (comprehensive)** — Cover the full scope, not just the happy path. Update related call sites, docs, and `docs/progress.md`. Don't leave half the task for "later."
- **完备测试 (fully tested)** — Write tests AND run them. Per 07-integrity §2, "verified" requires actual execution output — paste the command and result. Untested code is not done.
- **诚实 (honest)** — If something is blocked by an external resource, mark it "⚠️ code ready, verification pending: [reason]" — never ✅ it. Distinguish done from blocked.

## Step 3: Drive

Keep going until the completion conditions are met. While driving:
- Make reasonable decisions and keep moving — note them, don't stop to ask about trivia.
- The discipline rules still apply: 3 consecutive failures → pause and regroup; scope changes → re-align; anything irreversible or outward-facing → confirm first.
- Don't declare partial success to exit early. If you feel the urge to stop before the bar is met, that urge is the signal to push through or report the specific blocker — not to lower the bar.

## Step 4: Report on completion

When the completion conditions are met, give a short close-out:

```
FINISH — [task]
Done: [each deliverable + how it was verified — paste key command output]
Quality bar: 扎实 [✓/note] · 全面 [✓/note] · 完备测试 [✓/note]
Blocked (if any): [item — why, what's needed]
```

If any part is blocked rather than done, say so plainly. A truthful "90% done, X blocked on Y" beats a false ✅.
