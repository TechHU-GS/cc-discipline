# [PROJECT_NAME] — CLAUDE.md

> General discipline rules are auto-injected via `.claude/rules/`. This file is for project-specific information only.

---

## Project Overview

- **Project name**: [PROJECT_NAME]
- **One-line description**: [TODO — what this project aims to achieve]
- **Tech stack**: [TODO]
- **Key constraints**: [TODO — e.g., performance requirements, compatibility, security]

---

## Project Structure

[TODO — describe directory structure and module responsibilities]

```
├── src/          ← [TODO]
├── tests/        ← [TODO]
├── docs/
│   ├── progress.md      ← Progress and decision log (maintained by Claude, do not edit manually)
│   └── debug-log.md     ← Debug session log (maintained by Claude)
└── .claude/
    ├── rules/           ← Auto-injected rules
    ├── hooks/           ← Enforced hooks
    └── agents/          ← Reviewer & investigator subagents
```

---

## Common Commands

[TODO — build, test, lint, run commands]

```bash
# Build
# [TODO]

# Test
# [TODO]

# Lint / Type Check
# [TODO]

# Run / Simulate
# [TODO]
```

---

## Project Tools

<!-- Claude: when you create a helper script, tool, or reusable one-liner during a session,
     register it here IMMEDIATELY. Don't wait for /commit — do it when you create it.
     Next session's Claude will thank you. -->

<!-- TEMPLATE:
### [tool name]
- **Path**: `path/to/script`
- **Purpose**: what it does, when to use it
- **Usage**: `exact command to run [with args]`
- **Created**: [date] — [why it was needed]
-->

---

## Code Style

[TODO — team conventions]

---

## Known Pitfalls

[TODO — project-specific gotchas, examples:]
- [e.g., Module X's interface looks like REST but is actually WebSocket]
- [e.g., Database migrations must be backwards-compatible]
- [e.g., Third-party library v2 API has breaking changes, we're pinned to v1]

---

## Compact Supplement

When compacting, in addition to general rules (preserve task objectives, progress, decisions), also preserve:
- [TODO — project-specific context that must be retained]

---

## Decision Log

| Date | Decision | Reason | Impact |
|------|----------|--------|--------|
| | | | |
