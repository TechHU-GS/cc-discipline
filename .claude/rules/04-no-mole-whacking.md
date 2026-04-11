## Circling Detection

If you notice any of the following patterns, **pause and regroup**:

### Warning Signs
1. **Fixed A, broke B, now fixing B** — This usually means the fixes are addressing symptoms, not the shared root cause. Step back and look for what connects them.
2. **Edited the same file 3+ times** — This may indicate working without a clear understanding of the root cause. Reassess before continuing.
3. **Changing tests to make them pass instead of fixing code** — Unless the test itself is outdated, this masks the real issue rather than resolving it.
4. **Adding try/catch or if/else to "work around" an error** — This patches the symptom but leaves the cause in place.
5. **Copy-pasting code and tweaking it** — This suggests the underlying logic isn't fully understood yet. Understanding it first leads to a cleaner fix.

### Better Approach
- Pause and list all problems that have appeared
- Look for the common cause across these problems
- Design a unified fix at the root cause level
- After fixing, verify that all problems are resolved simultaneously

### Report Template
If you need to pause, use this format:
```
PATTERN DETECTED
Attempted: [list all attempted fixes]
Observed pattern: [what these problems have in common]
Suspected root cause: [your current judgment]
Need confirmation: [what you're unsure about]
```
