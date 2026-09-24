# TODO

> Open work only. When an item is done, delete it — what happened belongs in `docs/progress.md`, and git history keeps the old list.
> Claude adds items when you ask it to note something down and when it defers work itself. Edit this file freely.

## Now

- [ ] Dogfood the committed 2026-09-23/24 work in this repo, then decide on publishing. Until a release, every install keeps the old git-guard and its 14 bypasses; the npm token rotation (Later) comes first

## Later

- [ ] Guard the PowerShell tool: git-guard is registered for `Bash` only and exits 0 for any other tool name, so git run through PowerShell — the primary shell on MS-01 — is never checked. Needs a PowerShell quoting mode in the parser (backtick escapes, `''`, no backslash escapes) and matcher `Bash|PowerShell`; jq-less upgrades never touch an existing settings.json, so MS-01's 10 installs need a scripted edit at rollout. Unverified: that the hook payload's `tool_name` is `PowerShell` — revisit: once the awk parser has shipped.
- [ ] Same-class git-guard gaps outside Codex's 14, left out on 2026-09-23 by the user's choice: `switch -f`/`--discard-changes`; `checkout <commit> <path>` (two positionals, no `-b`/`-B`/`--orphan`); pushes that delete trunk (`--delete main`, `origin :main`, `--mirror`); and, deliberately lower, `stash drop`/`clear` and `branch -f`/`-M` (recoverable, prone to false positives) — revisit: once the awk parser has shipped, when each becomes one rule plus tests.
- [ ] Explicit error handling for `init.sh`'s `cp` and `rm` steps on Windows, where `set -e` is off, so a partial failure cannot write the new version marker — revisit: when init.sh's install steps next change.
- [ ] Confirm the duplicate git-guard registrations are gone on mac-mini (11, 9 and 9) and techhu-7940 (`techhu-devices`, 2); a jq upgrade now removes them — revisit: at the next rollout.
- [ ] Rotate the npm token that was pasted in chat on 2026-06-05 — revisit: before the next `npm publish`. The highest-severity open item, and only the user can do it: anyone holding it can publish under this package name, which 25 installs pull with `npx @latest`.
- [ ] Held audit items: `01`'s phases and numeric rubric, `00` §2 and §6, `05` §5, and `03`'s "When tasks feel overwhelming" — revisit: after two to three weeks of dogfooding on Opus 5.5, or once the debug-log check below is done. Each has measured provenance on older models. If `01` changes, `self-check/SKILL.md:41` must change with it.
- [ ] Check whether `docs/debug-log.md` in the 25 installs contains any hypothesis rows at all — revisit: before deciding the held audit items. If it never does, `01`'s procedure isn't being followed in practice.
- [ ] Decide where new progress.md milestones go: here, 17 of 30 sit under `## Rule Ledger`, because entries are appended at the end of the file and the template ends with the Rule Ledger — revisit: before publishing the `docs/todo.md` change, since both touch the progress template.
- [ ] Update `~/.claude/CLAUDE.md` by hand on the three machines — `upgrade` never touches it, and this round changed it twice (the subagent line; progress/todo mentions) — revisit: when these changes are published.
- [ ] Narrow action-counter's Phase check to write actions; today it fires on the first three actions of any kind, reads and research included — revisit: when `action-counter.sh` is next edited. Needs a matrix test.
- [ ] Measure the Edit-path hooks' latency on macOS (mac-mini) and with jq present; apart from git-guard (~10ms on macOS, ~20ms on techhu-7940, 2026-09-23), every figure is Windows Git Bash without jq — revisit: before the field-extraction rewrite, whose payoff depends on it.
- [ ] Add `project_doc_fallback_filenames = ["CLAUDE.md"]` to `~/.codex/config.toml`, so Codex reviews see each repo's CLAUDE.md without an AGENTS.md — the user's own config; revisit: the next time a Codex review misses something CLAUDE.md states.
- [ ] Try `/codex:adversarial-review` for plan reviews: it is hardcoded read-only and accepts focus text, where `/codex:rescue` defaults to write — revisit: at the next `/coplan` review. Unknown whether it can read a gitignored plan file.
- [ ] Skills audit pass: `self-check/SKILL.md:34` is a fourth copy of the compaction guidance, and `/coplan` should ask for absolute paths and reproduction steps when a plan cites sources outside the repo — revisit: after the rule changes are published.
- [ ] Plugin-based distribution of hooks, skills and agents — revisit: after this round has been rolled out, using that rollout as evidence of what the current path costs. Needs its own `/think`: it would remove the jq-dependent settings merge and the SSH rollout, at the cost of namespaced skill names and of in-place edits to plugin skills.
- [ ] `pre-edit-guard` field-extraction rewrite (~60 ms in a prototype, against ~150 ms exempt / ~650 ms source today) — revisit: once a malformed-payload fixture matrix exists.
- [ ] Installs upgraded from before 2.12.2 never retire skills, because they have no manifest (seen on `HUB_Rev1_FW`) — revisit: if an install still carrying `/finish` or `/retro` turns up.
- [ ] Merge `coplan/SKILL.md.new` into the locally edited copy in `HUB_Rev1_FW` on techhu-7940 — revisit: next time work happens in that repository.
