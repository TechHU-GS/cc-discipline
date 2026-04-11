---
name: summary
description: Summarize current session context for high-quality /compact. Run before compacting to preserve what matters.
---

You are about to compact this session. A bad compact loses critical context and degrades work quality. Your job is to write a compact option that preserves what matters most.

## What to do

### 1. Scan current session state

Quickly identify:
- What task(s) are we working on? What's the overall goal?
- What decisions have been made and why?
- What approaches were tried and rejected (and why)?
- What is the current state of implementation? (done / in progress / blocked)
- What are the key constraints and gotchas discovered?
- What are the next steps?

### 2. Check knowledge files

Read `docs/progress.md` — is it up to date? If not, update it NOW before compacting. This is your primary insurance against context loss.

Also check: are there unsaved learnings that should go into memory?

### 3. Write the compact option

Output a compact option string that the user can copy into `/compact [option]`. The string should:

- Lead with the current task and its status
- Include key decisions with their reasoning (not just the decision)
- Include rejected approaches (so Claude doesn't retry them)
- Include discovered constraints and gotchas
- Include the immediate next steps
- Be specific — "working on auth" is useless, "refactoring OAuth2 token refresh in src/auth/refresh.ts because the current implementation doesn't handle token rotation, decided to use sliding window approach over fixed expiry" is useful

Format:
```
/compact [your option string here]
```

### Rules

- **Be specific, not generic.** Every word in the option should carry information that helps post-compact Claude continue at full quality.
- **Include the "why", not just the "what".** "Using approach A" is less useful than "Using approach A because B had race condition issues we discovered in message #45."
- **Include negative knowledge.** What NOT to do is as valuable as what to do. "Don't use the built-in cache — it doesn't support TTL, we already tested this."
- **Keep it under 500 words.** The option needs to be dense, not exhaustive. If you need more, put the details in progress.md and reference it.
- **Don't overlap with progress.md.** The option should complement progress.md, not duplicate it. Focus the option on session-specific context that progress.md might not capture (conversation dynamics, user preferences expressed this session, subtle constraints).
