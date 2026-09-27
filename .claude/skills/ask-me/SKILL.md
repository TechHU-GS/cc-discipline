---
name: ask-me
description: Put a decision to the user so they can answer in one step — a few lines of background, then a single- or multi-select question with the recommended option first.
when_to_use: When the user types /ask-me or says "带着背景和选项问我" / "带着选项问我" / "ask me with options". On your own, only when you are blocked on something that is the user's call (scope, approach, a trade-off, anything irreversible or outward-facing) or on intent or environment that no file or command can tell you. Not for what the code, the docs or a conventional default settles.
---

Ask the user a question they can answer in one step.

This replaces two failures. One is a wall of text with the real question buried at the end. The other is a bare open question the user cannot answer, because the context needed to answer it is in your head, not theirs.

## 1. Decide what actually needs asking

- **Topic.** If the user gave arguments, that is the topic. Otherwise it is whatever decision is pending in the conversation: the thing you would otherwise ask in prose, or quietly guess.
- **Settle what you can first.** Read the file, run the command, check `docs/progress.md` and `docs/todo.md`. Ask only what is left, which should be the user's preferences and direction, or facts only they know. A question whose answer is in the repo wastes the user's turn.
- **Nothing pending?** If nothing is actually open, say so in one line and stop. Do not invent a question so that the skill has something to do.

## 2. Background first, in plain text, briefly

Write three to six lines before the question, covering only what the user needs in order to choose:

- what is already settled;
- where things are stuck, and why it is the user's call: a trade-off, a preference, a risk;
- anything you checked that changes the options, with `file:line` when it helps.

Save the analysis of each option for that option's description. If the background runs past about six lines, you are explaining too much or asking too early.

## 3. Ask with AskUserQuestion

- **Questions.** Ask one to four per call, and only ones whose answer changes what you do next. Put related questions in the same call rather than drip-feeding them. Write them in the user's language.
- **Options.**
  - Give two to four per question, and make them genuinely different.
  - Do not add an "Other" option; the tool provides one.
  - Put your recommendation first and mark it in the user's language, "（推荐）" or "(Recommended)". Its description says why in one sentence.
  - If you have no basis for recommending one, say that in the background rather than marking one at random.
- **Descriptions.** Each option's description says what happens if it is chosen and what that costs. Do not restate the label.
- **Header.** At most 12 characters.
- **multiSelect.** Use it only when the choices combine, for example which items to include. An empty multi-select answer is ambiguous: ask again rather than assume.
- **preview.** Use it when the user needs to compare concrete artifacts: code, configuration, layouts. It works for single-select questions only.

## 4. After the answer

- **Act on what was answered, and only that.** An answer to "which approach" chooses the approach. It is not approval for irreversible or outward-facing steps, such as publishing, pushing or deleting; those still get their own confirmation.
- **"Other" with free text.** Treat it as the user's own words. If it changes the premise, re-plan instead of squeezing it into one of your options.
- **Question rejected or interrupted.** Stop and wait: the user is about to tell you something. Do not re-ask the same questions. When they reply, work out which of your assumptions their correction overturns.

## When the tool is unavailable

Some contexts block the question tool: `/self-check` lists it under `disallowed-tools`, and non-interactive runs have no UI. Fall back to text:

1. Give the same background.
2. Number the questions and letter the options, recommendation first and marked, so the user can reply "1A 2B".

Keep it as short as the tool version would be.
