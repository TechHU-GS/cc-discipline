---
name: retro
description: Find friction, remove friction. Quick post-task review that makes this project's workflow smoother and feeds improvements back to cc-discipline.
---

Find friction. Remove friction. That's it.

## What to do

Quickly scan what just happened — `git log --oneline -10` and any hook triggers you remember. Then output **only friction and insights**, in this format:

```
RETRO — [date]

Friction:
- [what got in the way] → fix: [specific actionable change]

Insights:
- [something learned that should survive this session]

Framework:
- [cc-discipline improvement, if any — skip if none]
```

Rules:
- **Only friction** — Don't list what went well. Smooth things don't need attention.
- **Only actionable** — Every friction item must have a "→ fix:" with a concrete change (adjust a threshold, add to CLAUDE.md, update memory, exempt a path).
- **Only new** — Don't repeat friction that's already been addressed or recorded in memory.
- **Be specific** — "streak-breaker was annoying" is not useful. "streak-breaker triggered 3x on config.yaml during template fill → fix: add config.yaml to docs/ exempt path, or raise config threshold to 10" is useful.
- **Framework items are rare** — Most friction is project-specific. Only flag framework issues if the same problem would hit other projects too.
- **Keep it short** — 3-5 items max. If you can't find friction, say "no friction found" and move on. An empty retro is a good sign.

## After output

Present the items. User decides:
- "fix it" → apply the changes
- "remember it" → write to memory via /commit
- "skip" → move on

Do not auto-apply. Do not pad. Do not turn this into a report.
