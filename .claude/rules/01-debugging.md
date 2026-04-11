## Debugging Process (follow in order — each phase builds on the last)

### Phase 1: Gather (read only — no file modifications yet)
- Read the full error message and stack trace
- Confirm reproduction conditions
- Check related tests and logs
- **Think from first principles**: what does the code actually do at this point? Trace the data flow. Resist pattern-matching ("this looks like error X") — understand the mechanism.

### Phase 2: Hypothesize (read only — no file modifications yet)
- List >=3 possible causes
- Annotate each with supporting/contradicting evidence
- Record hypotheses in `docs/debug-log.md`
- **Keep all hypotheses open at this stage** — none is "the root cause" until evidence says so

### Phase 3: Verify (test hypotheses before fixing)
- Design a minimal experiment to confirm/refute EACH hypothesis
- Run the experiment and record results
- Eliminate hypotheses one by one with evidence
- Update debug-log as each hypothesis is eliminated
- **Only after ≥2 hypotheses are eliminated with evidence may you identify a root cause**

### Phase 4: Fix
- State which hypotheses were eliminated and how
- Explain how the fix addresses the confirmed root cause (not just the symptoms)
- Run all related tests after fixing

### Common pitfalls (these undermine the process)
- Seeing an error and immediately changing code to "try something" — this skips understanding and often creates new problems
- Declaring "root cause" after seeing a single error message — at that point it's still a hypothesis, not a conclusion
- Stopping investigation after the first plausible explanation — plausible is not the same as confirmed
- Reasoning by analogy ("I've seen this before, usually it's X") instead of tracing what the code actually does
- Declaring a problem "impossible" or "an upstream limitation" before exhausting all local causes — local causes are more common and more controllable
