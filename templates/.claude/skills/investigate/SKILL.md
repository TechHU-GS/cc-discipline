---
name: investigate
description: Multi-agent cross-investigation. Two modes — research (explore from scratch) and review (challenge existing proposal). Spawns parallel agents per dimension, synthesizes with dialectical cross-check.
---

## Mode detection

Determine which mode based on user input:

- **Research mode** — User gives a topic/question with no existing proposal. Goal: build comprehensive understanding before forming an opinion.
- **Review mode** — User gives an existing document, proposal, or design. Goal: stress-test it from multiple angles, find blind spots and weaknesses.
- **Simulate mode** — User gives a plan and wants to "dry run" it. Goal: walk through execution step by step, let hidden problems surface naturally.

State which mode you're using and why.

---

# Research Mode

You are about to research a topic or design a solution. **Do NOT go deep on one angle.** Your job is to see the full picture before converging.

## Step 1: Decompose into dimensions

Before researching anything, identify 3-5 independent dimensions of the problem. Ask yourself:
- What are the different angles this could be viewed from?
- What are the stakeholders / affected systems / competing concerns?
- What would a devil's advocate focus on?

Output the dimensions as a numbered list. Each dimension should be genuinely different, not sub-points of the same thing.

Example for "should we migrate from REST to GraphQL?":
1. **Performance & scalability** — latency, payload size, caching implications
2. **Developer experience** — learning curve, tooling, debugging
3. **Existing ecosystem** — what breaks, migration cost, backward compatibility
4. **Security** — query complexity attacks, authorization model changes
5. **Business** — timeline pressure, team skills, client requirements

## Step 2: Parallel investigation

Spawn one subagent per dimension. Each agent:
- Investigates ONLY its assigned dimension
- Reads relevant code/docs for that angle
- Lists findings with evidence (file paths, code references, data)
- Flags risks and unknowns specific to that dimension
- Does NOT try to propose a final solution — just reports findings

Launch agents in parallel, not sequentially.

## Step 3: Synthesize

After all agents return, synthesize in the main conversation:

### Cross-check matrix
For each dimension pair, ask: do the findings conflict?

```
         | Dim 1 | Dim 2 | Dim 3 | Dim 4 |
Dim 1    |   —   | conflict? | aligned? | ? |
Dim 2    |       |   —   | ? | ? |
...
```

### Blind spots
- What did NO agent cover? What's missing from all reports?
- What assumptions are shared across all dimensions (and might be wrong)?
- What would someone who disagrees with ALL agents say?

### Integrated findings
Combine into a unified picture. Flag where dimensions support each other and where they pull in different directions.

## Step 4: Present

Output the integrated findings to the user. For each key finding:
- Which dimensions support it
- Which dimensions challenge it
- Confidence level (strong / moderate / weak)
- What would change your mind

**Do NOT present a single recommendation without showing the tensions.** The user needs to see the trade-offs, not just your favorite answer.

---

# Review Mode

You have an existing document, proposal, or design to evaluate. **Do NOT just validate it.** Your job is to find what's wrong, what's missing, and what would break.

## Step 1: Read and summarize

Read the document completely. Summarize its core claims and assumptions in 3-5 bullet points. Confirm with the user: "Is this what this document is proposing?"

## Step 2: Decompose into challenge dimensions

Identify 3-5 angles to challenge the proposal from:
- **Feasibility** — Can this actually be built/done as described? What's underestimated?
- **Alternatives** — What approaches did the proposal NOT consider? Why might they be better?
- **Failure modes** — How could this fail? What happens when assumptions are wrong?
- **Scalability / long-term** — Does this hold up at 10x scale or in 2 years?
- **Domain-specific** — Does this violate any known constraints of the specific domain?

Adapt dimensions to the document's domain. Not all apply to every proposal.

## Step 3: Parallel challenge agents

Spawn one agent per challenge dimension. Each agent:
- Takes the proposal's claims at face value, then tries to **break** them
- Reads relevant code/docs to verify the proposal's assumptions against reality
- Produces: what's solid, what's questionable, what's wrong, what's missing
- Includes evidence (code references, counterexamples, data)

## Step 4: Synthesize review

### Verdict per claim
For each core claim from Step 1:
- **Holds** — evidence supports it
- **Questionable** — partially true but has gaps
- **Wrong** — contradicted by evidence
- **Unverifiable** — no way to confirm from available information

### Blind spots
What did the document completely fail to consider?

### Strongest objection
If you had to argue AGAINST this proposal in one paragraph, what would you say?

### Constructive output
Don't just tear it apart. For each issue found, suggest what would fix it.

---

# Simulate Mode

You have a plan or proposal. Instead of analyzing it on paper, **walk through it as if you're actually executing it**, step by step. Let problems surface naturally.

## Step 1: Extract execution steps

Read the plan and break it into concrete sequential steps. For each step, identify:
- What it requires (inputs, resources, preconditions)
- What it produces (outputs, state changes)
- What it assumes

Present the steps and confirm with the user: "Is this the execution sequence?"

## Step 2: Assign simulation agents

Spawn one agent per phase or critical step. Each agent:
- **Actually attempts to execute** (or traces through execution) of their assigned step
- Works with real files, real code, real environment where possible
- If can't actually execute (e.g., deployment plan), does a detailed walkthrough: "At this point I would need X, but looking at the current state, X is not available because..."
- Reports for each step:
  - **Went as planned** — step worked / would work as described
  - **Missing precondition** — "Step 3 assumes X exists, but step 2 doesn't create it"
  - **Harder than expected** — "This was described as 'configure Y' but actually requires Z, which takes much longer"
  - **Hidden dependency** — "This step silently depends on A, which the plan doesn't mention"
  - **Order problem** — "This needs to happen before step N, not after"
  - **Ambiguity** — "The plan says 'set up the database' but doesn't specify which schema, migration, or seed data"

## Step 3: Compile discoveries

After all agents return, compile a simulation report:

### Execution timeline
Show the steps as actually executed (vs. as planned). Highlight where reality diverged from plan.

### Issues discovered
For each issue:
- **Severity**: blocker / significant / minor
- **When discovered**: which step
- **Root cause**: why the plan missed this
- **Fix**: specific change to the plan

### Missing steps
Steps that the plan didn't include but simulation revealed are necessary.

### Revised plan
Present the original plan with all fixes, missing steps, and reordering applied. Mark what changed and why.

## Step 4: Present to user

Show the simulation report. Let the user decide which fixes to adopt. The revised plan is a suggestion, not a mandate.

---

## When to use this skill

- Researching a technology choice or architectural decision
- Investigating a complex bug with multiple possible root causes
- Evaluating a migration or major refactor
- **Reviewing an existing proposal, RFC, design doc, or plan**
- **Stress-testing your own plan before presenting it to stakeholders**
- **Simulating execution of a plan before committing to it — technical, engineering, or operational**
- Any situation where you catch yourself going deep on one angle and ignoring others
- When the user says "you're being narrow" or "what about X?" — that's a sign you needed this from the start
