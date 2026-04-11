## Python Discipline

### Code Quality
- Run lint/type check after modifications (use whatever the project has configured: ruff, mypy, pyright, etc.)
- Type annotations: new code must have type hints; add them to old code when modifying it
- Import ordering follows project conventions (typically managed by isort or ruff)

### Dependency Management
- Ask before adding new dependencies — is it truly needed? Is there a stdlib alternative?
- Confirm dependency version constraints — don't leave versions unconstrained, and don't pin too tightly

### Testing
- Run related tests after modifying logic
- First confirm which test framework the project uses (pytest? unittest?) and the run command — don't assume
- When tests fail, don't change the test to make it pass — first determine if the test is outdated or the code has a bug

### Prohibited
- No bare `except:` or `except Exception:` swallowing all exceptions
- No rewriting an entire module without understanding the existing code
- No introducing `os.system()` — use `subprocess.run()` with proper error handling
