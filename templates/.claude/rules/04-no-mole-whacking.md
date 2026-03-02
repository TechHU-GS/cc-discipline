## Mole-Whacking Detection

If you find yourself doing any of the following, **stop immediately**:

### Red Flags
1. **Fixed A, broke B, now fixing B** — You're whack-a-mole-ing. Step back and find the common root cause.
2. **Edited the same file 3+ times** — You may be going in circles. Stop and reassess.
3. **Changing tests to make them pass instead of fixing code** — Unless the test itself is genuinely wrong, this is hiding problems.
4. **Adding try/catch or if/else to "work around" an error** — This is symptom patching, not fixing.
5. **Copy-pasting code and tweaking it** — You may be guessing without understanding the underlying logic.

### Correct Approach
- Stop and list all problems that have appeared
- Look for the common cause across these problems
- Design a unified fix at the root cause level
- After fixing, verify that all problems are resolved simultaneously

### Report Template
If you need to stop, use this format:
```
MOLE-WHACKING ALERT
Attempted: [list all attempted fixes]
Observed pattern: [what these problems have in common]
Suspected root cause: [your current judgment]
Need confirmation: [what you're unsure about]
```
