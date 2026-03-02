## Context Management

### Proactive Checkpoints
- After completing a milestone → update `docs/progress.md` (current state, key decisions, next steps)
- During debugging → update `docs/debug-log.md` (hypotheses, evidence, elimination results)
- When making architectural decisions → record the decision and reasoning in progress.md

### Research Isolation
- When extensive code reading is needed → use subagents, don't read large volumes of files in the main conversation
- After subagent returns a summary, make decisions in the main conversation based on the summary

### Compact Strategy
- If context is about to fill up → proactively warn the user
- Ensure progress.md is up to date before compact
- First thing after compact: read `docs/progress.md` to restore context

### Prohibited
- Do not start a large new task when context is nearly full
- Do not mix unrelated tasks in a single conversation
