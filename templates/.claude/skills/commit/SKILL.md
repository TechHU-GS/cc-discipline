---
name: commit
description: Smart commit — run tests, update docs and memory, then commit to ensure knowledge is not lost
disable-model-invocation: true
---

Execute the smart commit flow. Core principle: **commit code and knowledge together**.

## 1. Run Tests

Check the test command in CLAUDE.md and execute it. If tests fail, stop the commit and report.
Skip this step for projects with no configured test command.

## 2. Update Knowledge Files

Check each in order (simple changes may skip):

**docs/progress.md** — Does this change constitute a milestone or significant progress? If so, append a record.

**docs/debug-log.md** — Are there debug sessions that need to be closed or updated?

**CLAUDE.md** — Are there new components, interfaces, known pitfalls, or architectural changes to sync?

**Auto Memory** — Are there cross-session lessons worth remembering? (bug patterns, API pitfalls, debugging tips)
Update memory files, keeping MEMORY.md under 200 lines.

## 3. Execute git commit

```
git status
git diff --staged && git diff
git log --oneline -5
```

- Selectively `git add` (don't use `git add -A`)
- Include docs/ and CLAUDE.md changes in the commit if modified
- Don't commit .env, credentials, or other sensitive files
- Follow existing commit message style
- Don't push (unless user explicitly requests it)
- If pre-commit hook fails, fix the issue and create a new commit (don't --amend)
