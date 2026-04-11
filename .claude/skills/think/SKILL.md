---
name: think
description: Stop and think before coding. Read context, ask questions, propose approaches, self-review, wait for user choice. Use when starting any non-trivial task.
---

You are about to start a task. **Do NOT write any code yet.** Your job right now is to think clearly and align with the user before acting.

## Step 0: Read first

Before asking anything, read the relevant code and docs. Spend 1-2 minutes understanding what already exists:
- Read files that will be affected
- Check existing patterns, conventions, and architecture
- Look at recent commits for context on current direction

This turns your questions from generic ("what framework?") into informed ("I see you're using X pattern in module Y — should the new feature follow the same pattern, or is there a reason to diverge?").

**Skip this step only if the task is purely conceptual with no existing code.**

## Step 1: Gauge complexity

Before diving deep, assess the task size:

- **Small** (rename, fix typo, add a config field): Skip to Step 4 — just state what you'll do and do it. Don't over-process trivial work.
- **Medium** (new feature, refactor a module, fix a non-obvious bug): Run Steps 2-5 normally.
- **Large** (crosses multiple subsystems, changes architecture, affects many files): Flag it. Propose decomposition into smaller tasks before designing a monolith solution.

State your assessment: "This looks [small/medium/large] because [reason]."

## Step 2: Understand

Ask 2-3 clarifying questions about the task. Focus on:
- What exactly should change? (scope)
- What should NOT change? (boundaries)
- How will we know it's done? (success criteria)

Rules:
- One message, all questions at once (don't drip-feed)
- Prefer multiple-choice over open-ended when possible
- Reference what you learned in Step 0 — ask about gaps in your understanding, not things you can read yourself
- If the task is already crystal clear from Step 0, say so and skip to Step 3

## Step 3: Propose

After the user answers (or if you skipped Step 2), propose **2-3 approaches**:

```
**Approach A: [name]**
- How: [1-2 sentences]
- Pros: ...
- Cons: ...
- Steps:
  1. [step] — done when: [acceptance criteria]
  2. [step] — done when: [acceptance criteria] (parallel with 1)
  3. [step] — done when: [acceptance criteria] (depends on 1+2)

**Approach B: [name]**
- How: [1-2 sentences]
- Pros: ...
- Cons: ...
- Steps:
  1. [step] — done when: [acceptance criteria]
  2. [step] — done when: [acceptance criteria] (parallel with 1)
  3. [step] — done when: [acceptance criteria] (depends on 1+2)

**Recommendation: [A/B/C] because [reason]**
```

Rules:
- Approaches must be genuinely different, not trivial variations
- If there's truly only one reasonable approach, say so — don't invent fake alternatives
- Include effort estimate for each (small / medium / large)
- Follow existing codebase patterns unless there's a strong reason not to
- Flag risks or unknowns you've spotted
- **Every step must have acceptance criteria** — "done when" must be observable and verifiable, not vague. Bad: "done when refactored". Good: "done when 3 methods extracted, each ≤20 lines, all tests pass"
- **Simplicity bias** — If a simple approach meets all requirements, list it first and recommend it. Do NOT lead with complex/elegant solutions unless the user signals they want that. "Simple but sufficient" beats "powerful but overkill".
- **Mark parallel opportunities** — In the steps, annotate which can run concurrently (via subagents/tasks) and which have dependencies. Don't default to sequential when parallel is possible.

## Step 4: Self-review

Before presenting to the user, challenge your own proposals:

- Am I overcomplicating this? Is there a simpler way I haven't considered?
- Am I solving the right problem, or a problem I invented?
- Does this match existing patterns in the codebase, or am I introducing unnecessary novelty?
- Did I miss an obvious approach that someone more familiar with this codebase would see?
- Would I be embarrassed by this proposal after reading more code?

If self-review reveals issues, revise your proposals before presenting. Don't show the user your first draft if you can already see it's flawed.

## Step 5: Wait

**Stop here. Do not proceed until the user picks an approach or gives a green light.**

Do not:
- Start coding "while waiting"
- Create files or scaffolding
- Run exploratory commands beyond what's needed for Step 0-3
- Say "I'll go ahead and start with Approach A" — that's the user's call

## When this skill ends

When the user confirms an approach, transition to implementation. You now have:
- Clear scope and boundaries from Step 0-2
- An agreed approach from Step 3
- Self-reviewed quality from Step 4
- Known risks flagged upfront

Carry these forward. If scope changes during implementation, pause and re-align rather than silently expanding.
