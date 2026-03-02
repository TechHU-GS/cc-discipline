## Phase Discipline

Claude must confirm which phase it's in before acting.

### Phases
- **Research**: read only, no edits, no plans, report findings
- **Plan**: discuss approach, write plan, no code edits
- **Implement**: execute the agreed plan, make code changes

### Rules
- If the user declares a phase, stay in it. Don't jump ahead.
- If the current phase is unclear, ask the user before proceeding.
- Transitioning between phases requires explicit acknowledgment.
