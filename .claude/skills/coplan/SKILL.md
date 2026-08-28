---
name: coplan
description: Write the plan under discussion to docs/current-plan.md so Codex can review it against the real code. Stacks after /think.
when_to_use: When a plan is worth a second opinion before building it — "coplan", "落个方案", "写下来给 codex 看", "把方案存一下" — or whenever /coplan is stacked after /think.
---

Write the plan under discussion to `docs/current-plan.md`, then stop.

This skill does not produce the plan and does not decide anything. It takes whatever is on the table — the approaches from `/think`, or a plan just described in conversation — and puts it where Codex can read it. Codex runs read-only from the repo root, so a plan **on disk** is one it can check **against the actual code**. That is the entire point: a plan pasted into a prompt can only be judged on its own terms, while a plan in the tree can be judged against what is really there.

If there is no plan on the table yet — no approaches from `/think`, nothing described in conversation — **say so and stop**. Point at `/think` instead. Do not invent a plan just to have something to write: a fabricated plan sent for review wastes a Codex run and produces confident feedback on something nobody proposed.

## What to write

**Overwrite the file completely.** One path, current version only — every earlier version survives in `git log -p docs/current-plan.md`, so nothing is lost and the directory never fills with dated files.

Include, in this order:

1. **Task** — what is being asked, in a sentence or two, framed the way the user framed it rather than the way you re-scoped it.
2. **Approaches** — two or three. For each: how it works, what it costs, what it gives up. If there is genuinely only one reasonable approach, say so and say why. Do not invent alternatives to fill the section.
3. **Recommendation** — which one, and the reason. A recommendation, not a survey.
4. **Assumptions to verify** — the highest-value section for a reviewer that has the repo. Every claim the plan rests on that you have *not* checked: "assumes this is only called from X", "assumes the migration runs before Y", "assumes no other caller depends on the old shape". Codex can open the code and tell you which of these are false. **A plan usually fails here, not in its logic.**
5. **Risks and unknowns** — what could go wrong, and what you could not determine.
6. **Out of scope** — what this deliberately does not touch, so a reviewer does not flag choices as omissions.

Write it for someone who has the codebase but was not in this conversation. No "as discussed above", no pronouns pointing at chat history.

## Then stop

Report the path and hand the review command over verbatim:

```
Plan written to docs/current-plan.md

To have Codex review it:
/codex:rescue 只评审方案不要修改任何文件，方案见 docs/current-plan.md
```

**Do not run the review yourself** — it costs time and quota, and a small plan does not need one. That call belongs to the user. **Do not start implementing either**: writing a plan down is not approval to build it.

## When stacked after /think

`/think /coplan <task>` is the intended pairing. `/think` produces the approaches and stops for the user's choice; `/coplan` puts them on disk on the way past.

Write the file with the approaches **still open**. The review is meant to inform the choice, not rubber-stamp one already made — so do not collapse the section down to your recommendation just because you have one.
