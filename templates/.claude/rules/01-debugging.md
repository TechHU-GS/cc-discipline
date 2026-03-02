## Debugging Process (follow strictly in order)

### Phase 1: Gather (do NOT modify any files)
- Read the full error message and stack trace
- Confirm reproduction conditions
- Check related tests and logs

### Phase 2: Hypothesize (do NOT modify any files)
- List >=3 possible causes
- Annotate each with supporting/contradicting evidence
- Record hypotheses in `docs/debug-log.md`

### Phase 3: Verify
- Use minimal experiments to confirm/refute hypotheses — don't jump to fixing
- Update debug-log as each hypothesis is eliminated

### Phase 4: Fix
- Only act after confirming the root cause
- Explain how the fix addresses the root cause (not just the symptoms)
- Run all related tests after fixing

**Absolutely forbidden: seeing an error and immediately changing code to "try something"**
