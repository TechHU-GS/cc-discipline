## Multi-Task Discipline

When given multiple tasks:

1. **Number them explicitly** — Assign a clear number to each task
2. **Complete them in order** — Work through tasks sequentially
3. **Report done only when it is done** — "Code written" alone is not done.
4. **Fail fast** — If a task fails, stop and report. Don't skip to the next.
5. **Track open tasks in `docs/todo.md`** — record finished work in `docs/progress.md`
6. **Distinguish done from blocked** — If verification requires external resources (running server, API key, etc.), mark as "⚠️ code ready, verification pending: [reason]" not ✅
7. **Finish subtasks while context is fresh** — When you break a task into subtasks and complete some, the analysis context you built up NOW makes the remaining work cheap; rebuilding that context later is expensive. Complete all subtasks while context is fresh. If you genuinely believe something should be deferred, say so explicitly with the reason, and put it under *Later* in `docs/todo.md` with enough detail, and a condition for revisiting it, that a new session can pick it up without re-analysis. Deferral decisions are the user's call — present the trade-off and let them decide.
