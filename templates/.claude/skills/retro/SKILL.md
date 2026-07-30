---
name: retro
description: Find friction, remove friction. Quick post-task review that makes this project's workflow smoother and feeds improvements back to cc-discipline.
---

Find friction. Remove friction. Record what the rules actually caught.

## What to do

Quickly scan what just happened — `git log --oneline -10` and any hook triggers you remember. Then output in this format:

```
RETRO — [date]

Friction:
- [what got in the way] → fix: [specific actionable change]

Saves:
- [rule/hook] caught [the specific real problem] — without it: [what would have shipped]

Insights:
- [something learned that should survive this session]

Framework:
- [cc-discipline improvement, if any — skip if none]
```

Rules:
- **Only actionable friction** — Every friction item must have a "→ fix:" with a concrete change (adjust a threshold, add to CLAUDE.md, update memory, exempt a path).
- **Only new** — Don't repeat friction that's already been addressed or recorded in memory.
- **Be specific** — "streak-breaker was annoying" is not useful. "streak-breaker triggered 3x on config.yaml during template fill → fix: add config.yaml to docs/ exempt path, or raise config threshold to 10" is useful.
- **Framework items are rare** — Most friction is project-specific. Only flag framework issues if the same problem would hit other projects too.
- **Keep it short** — 3-5 items per section max. If you can't find friction, say "no friction found" and move on. An empty friction list is a good sign.

Saves — read this before filling that section in:
- **A save is not "what went well."** Log a save only when a rule or hook *changed the outcome*: it caught a real mistake, blocked a real loss, or stopped a wrong turn that was already in motion. "The rules kept me disciplined" is not a save. "git-guard blocked `git reset --hard` while 40 min of uncommitted work was in the tree" is.
- **"no saves" is a real answer, and it is data.** Write it plainly rather than manufacturing one.
- **Why this section exists:** friction is visible and saves are invisible — a rule that works silently suppresses the very failure it was written for, so the only naturally measurable signal is its cost. With cost-only data every rule eventually looks like pure overhead and gets cut, including the ones that are still load-bearing. The save log is what makes it possible to judge, later and with evidence, whether a given rule still earns its place.

## After output

Append both Friction and Saves to a `## Rule Ledger` section in `docs/progress.md` (create the section at the end of the file if it isn't there yet), one dated line each. This accumulates the record across sessions — a single retro proves nothing, twenty of them decide which rules stay.

Then present the items. User decides:
- "fix it" → apply the changes
- "remember it" → write to memory via /commit
- "skip" → move on

Do not auto-apply fixes. Do not pad. Do not turn this into a report. (Appending to the ledger is not a fix — do that without asking.)
