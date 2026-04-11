## Multi-Task Discipline

When given multiple tasks:

1. **Number them explicitly** — Assign a clear number to each task
2. **Complete them in order** — Work through tasks sequentially
3. **Verify before marking done** — Per 07-integrity §2: paste the verification command and output. "Code written" alone is not done.
4. **Confirm after each** — After each task, stop and confirm completion (with evidence) before starting the next
5. **Fail fast** — If a task fails, stop and report. Don't skip to the next.
6. **Track progress** — Update `docs/progress.md` with task status
7. **Distinguish done from blocked** — If verification requires external resources (running server, API key, etc.), mark as "⚠️ code ready, verification pending: [reason]" not ✅
8. **Finish subtasks while context is fresh** — When you break a task into subtasks and complete some, the analysis context you built up NOW makes the remaining work cheap; rebuilding that context later is expensive. Complete all subtasks while context is fresh. If you genuinely believe something should be deferred, say so explicitly with the reason, and record enough detail in progress.md that a new session can pick it up without re-analysis. Deferral decisions are the user's call — present the trade-off and let them decide.
