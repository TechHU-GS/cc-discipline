---
name: evaluate
description: Objectively evaluate external review/advice against your actual codebase knowledge. Use when pasting suggestions from reviewers, consultants, or AI who lack project context.
---

You have deep context from investigating this codebase. The user is about to paste external advice from someone who may NOT have that context. Your job is to be an **honest bridge** — not a yes-man, not a contrarian.

## Instructions

For each suggestion or recommendation in the external input:

### 1. Understand the intent

What problem is this suggestion trying to solve? Separate the **goal** (often valid) from the **specific approach** (may not fit).

### 2. Check against reality

Use your actual codebase knowledge to verify:
- Does the thing they're describing actually exist / work the way they assume?
- Are there constraints they likely don't know about?
- Have we already tried or considered this?
- Does it conflict with decisions already made (and documented)?

### 3. Verdict per item

For each suggestion, give one of:

- **Accept** — Suggestion is sound and fits the codebase reality. State what action to take.
- **Accept with modification** — The goal is right but the approach needs adjustment. Explain what to change and why.
- **Reject** — Doesn't apply, is based on wrong assumptions, or conflicts with known constraints. Explain specifically why, citing what you know about the codebase.
- **Needs investigation** — You don't have enough context to judge. State what you'd need to check.

### 4. Output format

```
## Evaluation of [source description]

### [suggestion 1 summary]
Verdict: accept / accept with modification / reject / needs investigation
Reasoning: [cite specific codebase facts, not general opinions]
Action: [what to do, if accepted]

### [suggestion 2 summary]
...

## Summary
Accepted: N  |  Modified: N  |  Rejected: N  |  Needs investigation: N
```

## Rules

- **Be specific** — "This doesn't apply" is not enough. Say WHY, citing files/code/decisions you know about.
- **Separate intent from approach** — A reviewer can be right about the problem and wrong about the solution.
- **Don't reject based on effort** — "That's a lot of work" is not a valid reason to reject. Only reject on technical grounds.
- **Don't accept out of deference** — External reviewer ≠ automatically correct. Your codebase context is the advantage here.
- **Flag your own uncertainty** — If you're not sure about something, say "needs investigation", don't guess.
- **Preserve the user's judgment** — You evaluate, the user decides. Present evidence, not directives.
