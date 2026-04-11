## Pre-Edit Checklist

Before modifying this file, confirm each of the following:

- [ ] **I understand this file's role in the overall architecture** — If unsure, read surrounding files first
- [ ] **I know which other modules this change will affect** — If unsure, grep for references first
- [ ] **I am fixing the root cause, not patching symptoms** — If unsure, return to the debugging process
- [ ] **I have recorded the purpose of this change in `docs/progress.md`**
- [ ] **I know how to verify after the change** — Per 07-integrity: run it, paste output, or mark unverified

If any item is uncertain, resolving it first will make the edit smoother and avoid rework.

## Post-Edit Checklist

After writing or modifying code, before running it:

- [ ] **Syntax check** — Does the code compile/parse without errors? (e.g., `python -m py_compile`, `tsc --noEmit`, `go vet`)
- [ ] **Obvious errors** — No undefined variables, no wrong function signatures, no missing imports?
- [ ] **API correctness** — Are function/method calls using the right arguments, types, and return values? If unsure, read the API docs or source first.
- [ ] **Edge cases in your changes** — Did you handle empty inputs, None/null, off-by-one, etc.?

A 10-second syntax check catches errors that would otherwise cost 10-minute debug cycles. Always worth it.
